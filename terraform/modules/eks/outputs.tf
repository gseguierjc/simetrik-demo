output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster identifier"
  value       = module.eks_cluster.cluster_name
}

 output "ecr_repository_url" {
    description = "URL para hacer push/pull al repositorio ECR"
    value       = aws_ecr_repository.app.repository_url
  }

output "cluster_name" {
    description = "cluster name"
    value       = module.eks_cluster.cluster_name
}

output "cluster_arn" {
    description = "cluster arn"
    value       = module.eks_cluster.cluster_arn
}

output "cluster_ca_certificate" {
  description = "PEM-encoded certificate authority data para el cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "cluster_auth_token" {
  description = "JWT Bearer token para el API server de EKS"
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}