output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster identifier"
  value       = module.eks_cluster.cluster_id
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