output "oidc_provider_arn" {
  description = "ARN del proveedor OIDC creado para el EKS"
  value       = aws_iam_openid_connect_provider.this.arn
}
