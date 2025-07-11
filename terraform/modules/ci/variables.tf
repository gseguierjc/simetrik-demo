variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository URL for CI"
  type        = string
}

variable "source_repo_type" {
  description = "Type of source (GITHUB, CODECOMMIT, etc.)"
  type        = string
  default     = "GITHUB"
}
variable "source_repo_branch" {
  description = "Branch or commit ID to build"
  type        = string
  default     = "main"
}

variable "codebuild_compute_type" {
  description = "Compute type for CodeBuild"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "Docker image for CodeBuild environment"
  type        = string
  default     = "aws/codebuild/standard:6.0"
}
variable "codebuild_privileged" {
  description = "Enable Docker privileged mode"
  type        = bool
  default     = true
}

variable "buildspec" {
  description = "Path to buildspec file for CodeBuild"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL del repositorio ECR donde CodeBuild hará push"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster"
  type        = string
}