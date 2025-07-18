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
    bucket = "demo-eks-state-bucket-647187952873-b4b053c1"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-b4b053c1"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "k8s" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-b4b053c1"
    key    = "k8s/terraform.tfstate"
    region = "us-east-1"
  }
}


locals {
  # La ruta exacta puede variar según la versión del provider
  alb_dns = try(
    kubernetes_ingress_v1.grpc_ingress.status[0].load_balancer[0].ingress[0].hostname,
    ""
  )
}

# 7. EKS OIDC and IRSA for AWS LB Controller
data "aws_eks_cluster" "eks" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_security_group" "control_plane" {
  # Aquí usamos tu data.aws_eks_cluster.eks que ya existe
 id = data.aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id
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




data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}


data "aws_iam_openid_connect_provider" "eks_oidc" {
  arn = data.terraform_remote_state.k8s.outputs.oidc_provider_arn
}
# resource "aws_iam_openid_connect_provider" "eks_oidc" {
#   url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
# }

data "aws_iam_policy_document" "alb_irsa" {
  statement {
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks_oidc.arn]
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
    set { 
      name = "installCRDs" 
      value = "true" 
      }
    set { 
      name  = "enableCertManager" 
      value = "false" 
      }

  atomic  = true
  timeout = 600
}

# 9. gRPC Service
resource "kubernetes_service" "grpc" {
  metadata {
    name      = "grpc-server"
    namespace = "grpc-demo-server"
    labels    = { app = "grpc-app" }
  }
  spec {
    type     = "ClusterIP"
    selector = { app = "service-server" }
    port {
      name        = "grpc"
      port        = 50051
      target_port = 50051
      protocol    = "TCP"
    }
  }
}

resource "aws_route53_zone" "demo_internal" {
  name = "demo.internal"
}

# 5. Route53 zones
resource "aws_route53_zone" "local" {
 name = "internal"               # en vez de "local"
  vpc {
    vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  }
  tags = { Environment = "dev" }
}

# resource "aws_route53_record" "grpc_local_alias" {
#   zone_id = aws_route53_zone.local.zone_id
#   name    = "grpc.local"
#   type    = "A"
#   alias {
#     name                   = data.aws_lb.grpc_alb.dns_name
#     zone_id                = data.aws_lb.grpc_alb.zone_id
#     evaluate_target_health = true
#   }
# }

resource "aws_route53_record" "grpc_local_alias" {
  zone_id = aws_route53_zone.local.zone_id
  name    = "grpc.local"
  type    = "A"

  alias {
    name                   = data.aws_lb.grpc_alb.dns_name
    zone_id                = data.aws_lb.grpc_alb.zone_id    # o usar el HostedZoneID global de ALB
    evaluate_target_health = true
  }
}


resource "aws_route53_record" "grpc_alias" {
  zone_id = aws_route53_zone.demo_internal.zone_id
  name    = "grpc-demo-app"
  type    = "A"
  alias {
    name                   = data.aws_lb.grpc_alb.dns_name
    zone_id                = data.aws_lb.grpc_alb.zone_id
    evaluate_target_health = true
  }
}

 data "aws_lb" "grpc_alb" {
   depends_on = [ kubernetes_ingress_v1.grpc_ingress ]

   tags = {
     environment = "dev"
    app         = "grpc-demo"
   }
 }


 resource "aws_security_group_rule" "allow_https_to_alb" {
   description       = "Allow HTTPS (443) from anywhere to ALB SG"
   type              = "ingress"
   from_port         = 443
   to_port           = 443
   protocol          = "tcp"
   cidr_blocks       = ["0.0.0.0/0"]
   security_group_id = data.aws_security_group.control_plane.id
 }

resource "aws_security_group_rule" "allow_alb_to_nodes_grpc" {
  description              = "Allow gRPC (50051) from ALB SG to worker node SG"
  type                     = "ingress"
  from_port                = 50051
  to_port                  = 50051
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.eks.outputs.node_group_security_group_id
  source_security_group_id = data.aws_security_group.control_plane.id
}

 resource "aws_security_group_rule" "allow_cp_to_webhook" {
   description              = "Allow control plane  webhook 9443"
   type                     = "ingress"
   from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.control_plane.id
  source_security_group_id = data.aws_security_group.control_plane.id
}
 resource "kubernetes_secret" "grpc_tls" {
   metadata {
     name      = "grpc-tls"
     namespace = "grpc-demo-server"
   }
   type = "kubernetes.io/tls"
   data = {
     "tls.crt" = base64encode(
       aws_acm_certificate.selfsigned_import.certificate_body
     )
     "tls.key" = base64encode(
       aws_acm_certificate.selfsigned_import.private_key
     )
   }
 }
 # 2) Permitir HTTPS (443) desde internet al Security Group del ALB
 resource "aws_security_group_rule" "allow_alb_https" {
   description       = "Allow HTTPS (443) to gRPC ALB"
   type              = "ingress"
   from_port         = 443
   to_port           = 443
   protocol          = "tcp"
   cidr_blocks       = ["0.0.0.0/0"]
   security_group_id = data.aws_security_group.control_plane.id
 }
 # 3) Ingress para exponer gRPC por ALB en HTTPS
 resource "kubernetes_ingress_v1" "grpc_ingress" {
   depends_on = [ helm_release.alb_controller ]

   metadata {
     name      = "grpc-ingress"
     namespace = "grpc-demo-server"
     annotations = {
       "kubernetes.io/ingress.class"                        = "alb"
       "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
       "alb.ingress.kubernetes.io/target-type"              = "ip"
      
      "alb.ingress.kubernetes.io/backend-protocol"         = "HTTPS"
      "alb.ingress.kubernetes.io/backend-protocol-version" = "GRPC"

       "alb.ingress.kubernetes.io/listen-ports"             = jsonencode([{ HTTPS = 443 }])
       "alb.ingress.kubernetes.io/certificate-arn"          = aws_acm_certificate.selfsigned_import.arn
       "alb.ingress.kubernetes.io/healthcheck-protocol"     = "HTTPS"
       "alb.ingress.kubernetes.io/healthcheck-port"         = "traffic-port"
       "alb.ingress.kubernetes.io/healthcheck-path"         = "/grpc.health.v1.Health/Check"
       "alb.ingress.kubernetes.io/success-codes"            = "0"
       "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
       "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"

       "alb.ingress.kubernetes.io/tags" = "environment=dev,app=grpc-demo"
     }
   }

   spec {
     # Define TLS para el host grpc.local
    ingress_class_name = "alb"
     tls {
       hosts       = ["grpc.local"]
       secret_name = kubernetes_secret.grpc_tls.metadata[0].name
     }

     rule {
       host = "grpc.local"
       http {
         path {
           path      = "/"
           path_type = "Prefix"
           backend {
             service {
               name = kubernetes_service.grpc.metadata[0].name
               port {
                 number = 50051
               }
             }
           }
         }
       }
     }
   }
 }



resource "local_file" "grpc_crt" {
  content  = tls_self_signed_cert.grpc_cert.cert_pem
  filename = "${path.module}/certs/server.crt"
}

resource "local_file" "grpc_key" {
  content  = tls_private_key.grpc_key.private_key_pem
  filename = "${path.module}/certs/server.key"
}