provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "alb/terraform.tfstate"
    region = "us-east-1"
  }
}












data "aws_lb" "grpc_alb_local" {
  name = local.alb_name
  
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
   timeouts {
    create = "15m"
  }
  depends_on = [aws_route53_record.grpc_cert_validation]
}