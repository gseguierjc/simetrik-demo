state_bucket_name = "demo-eks-state-bucket"
acl = "private"
versioning = true
tags = {
  Environment = "demo"
  Project     = "eks"
}
force_destroy = true
region = "us-east-1"    

