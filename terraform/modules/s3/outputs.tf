output "s3_bucket_id" {
    description = "The name of the S3 bucket"
    value       = aws_s3_bucket.tfstate.id
}

output "s3_bucket_arn" {
    description = "The ARN of the S3 bucket"
    value       = aws_s3_bucket.tfstate.arn
}

output "s3_bucket_name" {
    description = "The domain name of the S3 bucket"
    value       = aws_s3_bucket.tfstate.bucket_domain_name
}

output "bucket_regional_domain_name" {
    description = "The regional domain name of the S3 bucket"
    value       = aws_s3_bucket.tfstate.bucket_regional_domain_name
}