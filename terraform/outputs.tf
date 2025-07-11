output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.network.vpc_id
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnets
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnets
}

output "grpc_security_group_id" {
  description = "Security Group ID allowing gRPC traffic"
  value       = module.network.grpc_security_group_id
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster identifier"
  value       = module.eks.cluster_id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.eks.ecr_repository_url
}

output "codebuild_project_arn" {
  value = module.ci.codebuild_project_arn
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket"
  value       = module.s3.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.s3_bucket_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3.s3_bucket_name
}