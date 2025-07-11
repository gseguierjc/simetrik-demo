terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}


data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "iam-role" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "iam/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# ECR repository for application images
resource "aws_ecr_repository" "app" {
  name = "${var.name}-app"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.name}-ecr"
  }
}

module "eks_cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = ">= 20.0.0"
  cluster_name    = "${var.name}-eks"
  cluster_version = var.cluster_version
  vpc_id          = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.network.outputs.public_subnets
   # Gestionar el aws-auth ConfigMap
  authentication_mode                       = "API_AND_CONFIG_MAP"  # :contentReference[oaicite:0]{index=0}
  enable_cluster_creator_admin_permissions  = true                  # :contentReference[oaicite:1]{index=1}

  cluster_endpoint_public_access        = true  
  cluster_endpoint_private_access       = true  
  cluster_endpoint_public_access_cidrs  = var.cluster_endpoint_public_access_cidrs # restringe acceso público a tu IP

 access_entries = {
    jean = {
      principal_arn = "arn:aws:iam::647187952873:user/terraform-demo-user"
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  # nodos gestionados en free-tier y con la política ALB Controller
eks_managed_node_groups = {
    eks_nodes = {
      min_size       = var.min_capacity
      max_size       = var.max_capacity
      desired_size   = var.desired_capacity
      instance_types = [var.node_instance_type]
      
    }
  }
  tags = {
    Name = var.name
  }
}
