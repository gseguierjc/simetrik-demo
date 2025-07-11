terraform {
  backend "s3" {
    bucket         = "demo-eks-state-bucket-647187952873-7632948f"      
    key            = "ci/terraform.tfstate"   # cambia por "ci/terraform.tfstate" 
    region         = "us-east-1"
    dynamodb_table = "demo-eks-state-bucket-lock"      # demo-eks-state-bucket-lock
    encrypt        = true
  }
}
