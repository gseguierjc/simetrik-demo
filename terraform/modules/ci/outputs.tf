
output "codebuild_project_arn" {
  description = "ARN del proyecto CodeBuild"
  value       = aws_codebuild_project.app.arn
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project for gRPC services"
  value       = aws_codebuild_project.app.name
}