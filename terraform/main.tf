terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "network" {
  source              = "./modules/network"
  name                = var.name
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  azs                 = var.azs
  azs_map             = var.azs_map
  grpc_port           = var.grpc_port
  private_cidr_blocks = var.private_cidr_blocks
}

module "eks" {
  source          = "./modules/eks"
  name            = var.name
  region          = var.region
  vpc_id          = module.network.vpc_id
  private_subnets = module.network.private_subnets
  cluster_version = var.cluster_version
}

module "ci" {
  source          = "./modules/ci"
  name            = var.name
  github_repo = var.github_repo
  buildspec = var.buildspec
  ecr_repository_url = module.eks.ecr_repository_url
  cluster_name = module.eks.cluster_name
  cluster_arn = module.eks.cluster_arn
}

module "s3" {
  source              = "./modules/s3"
  state_bucket_name   = var.state_bucket_name
  region              = var.region
}