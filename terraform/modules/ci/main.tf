// ------------------------------------------------
// Data Sources
// ------------------------------------------------
data "aws_caller_identity" "current" {}
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
# ------------------------------------------------
# IAM Role and Policies for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.name}-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:GetToken"
        ]
        Resource = data.terraform_remote_state.eks.outputs.cluster_arn # var.cluster_arn
      },
      {
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}



data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}


// ------------------------------------------------
// CodeBuild Project
// ------------------------------------------------
resource "aws_codebuild_project" "app" {
  name          = "${var.name}-grpc-build"
  service_role  = aws_iam_role.codebuild_role.arn

  source {
    type            = var.source_repo_type
    location        = var.github_repo
    git_clone_depth = 1
    buildspec       = var.buildspec
    build_status_config {
      context = "codebuild/${var.name}-grpc"
      target_url = ""
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    privileged_mode             = var.codebuild_privileged


    environment_variable {
      name  = "ECR_REPO"
      value = data.terraform_remote_state.eks.outputs.ecr_repository_url #var.ecr_repository_url
    }

    environment_variable {
      name  = "CLUSTER_NAME"
      value = data.terraform_remote_state.eks.outputs.cluster_name
    }
  }

}