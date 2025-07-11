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

data "terraform_remote_state" "iam" {
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

data "aws_eks_cluster" "this" {
  name = module.eks_cluster.cluster_name
}


data "aws_eks_cluster_auth" "this" {
  name = module.eks_cluster.cluster_name
}
data "tls_certificate" "eks_ca" {
  # Descarga el certificado TLS directamente del issuer OIDC
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}


resource "aws_iam_openid_connect_provider" "this" {
  # Usa la URL completa del issuer OIDC (incluye https://)
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_ca.certificates[0].sha1_fingerprint]
}
