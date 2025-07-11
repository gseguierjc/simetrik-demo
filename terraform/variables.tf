variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "demo"
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "azs_map" {
  description = "Mapping AZ names to indices for CIDR splits"
  type        = map(number)
  default     = {"us-east-1a" = 0, "us-east-1b" = 1}
}

variable "grpc_port" {
  description = "Port for gRPC communication in the network module"
  type        = number
  default     = 50051
}

variable "private_cidr_blocks" {
  description = "CIDR blocks allowed to access gRPC port"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "demo-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "github_repo" {
  description = "GitHub repository URL for CI/CD"
  type        = string
}

variable "buildspec" {
  description = "Name or path of the buildspec file for CodeBuild"
  type        = string
  default     = "buildspec.yml"
}

variable "state_bucket_name" {
  description = "Name of the S3/dynamo bucket"
  type        = string
  default     = "demo-s3-bucket"
}

variable "s3_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "s3_force_destroy" {
  description = "Force destroy the S3 bucket when deleting"
  type        = bool
  default     = false
}

variable "s3_block_public_access" {
  description = "Block all public access to the S3 bucket"
  type        = bool
  default     = true
}

variable "s3_tags" {
  description = "Tags to apply to the S3 bucket"
  type        = map(string)
  default     = {}
}