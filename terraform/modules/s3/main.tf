provider "aws" {
  region = var.region
}


data "aws_caller_identity" "current" {}

// Generar sufijo único para evitar colisiones en el nombre del bucket
resource "random_id" "suffix" {
  byte_length = 4
}

# 1. El bucket (sin acl/versioning/SSE inline)
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.state_bucket_name}-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"
  tags = {
    Name = "${var.state_bucket_name}-tfstate"
    Env  = "terraform-bootstrap"
  }
}

# 2. Bloquear todo acceso público
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Versioning habilitado
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 4. Cifrado SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 5. Tabla DynamoDB para locking
resource "aws_dynamodb_table" "lock" {
  name         = "${var.state_bucket_name}-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.state_bucket_name}-lock"
    Env  = "terraform-bootstrap"
  }
}
