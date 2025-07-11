name = "demo" // prfix for all resources
region = "us-east-1" // AWS region to deploy into
vpc_cidr = "10.0.0.0/16" // CIDR block for the VPC
azs = ["us-east-1a", "us-east-1b"] // List of availability zones for subnets
public_subnets  = ["10.0.1.0/24","10.0.2.0/24","10.0.3.0/24"]
private_subnets = ["10.0.101.0/24","10.0.102.0/24","10.0.103.0/24"]
github_repo = "https://github.com/gseguierjc/test"