terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Owner       = "demo-eks"
      Environment = "dev"
    }
  }
}

provider "tls" {}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# 2. Remote state: network & EKS
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}

# 3. TLS key + self-signed certificate for grpc.local
resource "tls_private_key" "grpc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "grpc_cert" {
  private_key_pem = tls_private_key.grpc_key.private_key_pem
  subject {
    common_name  = "grpc.local"
    organization = "dev"
  }
  validity_period_hours = 8760
  is_ca_certificate     = false
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

# 4. Import self-signed into ACM
resource "aws_acm_certificate" "selfsigned_import" {
  certificate_body  = tls_self_signed_cert.grpc_cert.cert_pem
  private_key       = tls_private_key.grpc_key.private_key_pem
  certificate_chain = tls_self_signed_cert.grpc_cert.cert_pem

  depends_on = [tls_self_signed_cert.grpc_cert]
  tags = {
    Name        = "selfsigned-grpc"
    Environment = "dev"
  }
}

# 5. Route53 zones
resource "aws_route53_zone" "local" {
  name = "local"
  vpc {
    vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  }
  comment = "Zona privada interna para .local"
  tags = { Environment = "dev" }
}

resource "aws_route53_zone" "grpc_zone" {
  name    = var.grpc_host
  comment = "Zona pública para gRPC vía ALB"
  tags    = { Environment = "dev" }
}

# 6. ACM Certificate with DNS validation
resource "aws_acm_certificate" "grpc_cert" {
  domain_name       = var.grpc_host
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = { Environment = "dev" }
}

resource "aws_route53_record" "grpc_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.grpc_cert.domain_validation_options :
    dvo.domain_name => dvo
  }

  zone_id = aws_route53_zone.grpc_zone.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 60
  records = [each.value.resource_record_value]
}

resource "aws_acm_certificate_validation" "grpc_cert_validation" {
  certificate_arn = aws_acm_certificate.grpc_cert.arn
  validation_record_fqdns = [
    for rec in aws_route53_record.grpc_cert_validation : rec.fqdn
  ]
  depends_on = [aws_route53_record.grpc_cert_validation]
}

# 7. EKS OIDC and IRSA for AWS LB Controller
data "aws_eks_cluster" "eks" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "alb_irsa" {
  statement {
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:${var.sa_name}"]
    }
  }
}

resource "aws_iam_role" "alb_irsa_role" {
  name               = "${data.terraform_remote_state.eks.outputs.cluster_name}-alb-irsa"
  assume_role_policy = data.aws_iam_policy_document.alb_irsa.json
  tags = { Environment = "dev" }
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${data.terraform_remote_state.eks.outputs.cluster_name}-alb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/alb-controller-policy.json")
  tags        = { Environment = "dev" }
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_irsa_role.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = var.sa_name
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_irsa_role.arn
    }
  }
}

# 8. Deploy AWS LB Controller via Helm
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.eks.outputs.cluster_name
  }
  set { 
    name = "region" 
    value = var.region 
    }
  set { 
    name = "vpcId"
    value = data.terraform_remote_state.network.outputs.vpc_id 
    }
  set { 
    name = "serviceAccount.create"
    value = "false" 
    }
  set { 
    name = "serviceAccount.name" 
    value = var.sa_name 
    }

  atomic  = true
  timeout = 600
}

# 9. gRPC Service
resource "kubernetes_service" "grpc" {
  metadata {
    name      = "grpc-service"
    namespace = "default"
    labels    = { app = "grpc-app" }
  }
  spec {
    type     = "ClusterIP"
    selector = { app = "grpc-app" }
    port {
      name        = "grpc"
      port        = 50051
      target_port = 50051
      protocol    = "TCP"
    }
  }
}

# 10. Ingress ALB for gRPC/TLS
resource "kubernetes_ingress_v1" "grpc_ingress" {
  metadata {
    name      = "grpc-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/backend-protocol-version" = "GRPC"
      "alb.ingress.kubernetes.io/listen-ports"             = jsonencode([{ HTTPS = 443 }])
      "alb.ingress.kubernetes.io/certificate-arn"          = aws_acm_certificate.selfsigned_import.arn
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      host = var.grpc_host
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.grpc.metadata[0].name
              port { number = 50051 }
            }
          }
        }
      }
    }
  }
}

# 11. Route53 Alias records to ALB
locals {
  alb_dns_name = kubernetes_ingress_v1.grpc_ingress.status[0].load_balancer[0].ingress[0].hostname
  alb_name     = element(split(".", local.alb_dns_name), 0)
}

data "aws_lb" "grpc_alb" {
  name = local.alb_name
}

resource "aws_route53_record" "grpc_alias" {
  zone_id = aws_route53_zone.grpc_zone.zone_id
  name    = var.grpc_host
  type    = "A"
  alias {
    name                   = data.aws_lb.grpc_alb.dns_name
    zone_id                = data.aws_lb.grpc_alb.zone_id
    evaluate_target_health = true
  }
}

data "aws_lb" "grpc_alb_local" {
  name = local.alb_name
}

resource "aws_route53_record" "grpc_local_alias" {
  zone_id = aws_route53_zone.local.zone_id
  name    = "grpc.local"
  type    = "A"
  alias {
    name                   = data.aws_lb.grpc_alb_local.dns_name
    zone_id                = data.aws_lb.grpc_alb_local.zone_id
    evaluate_target_health = true
  }
}
