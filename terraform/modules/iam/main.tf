resource "aws_iam_user" "eks_demo" {
  name = "eks-demo"
  path = "/system/"
}

resource "aws_iam_user_policy_attachment" "eks_demo_attach" {
  user       = aws_iam_user.eks_demo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-irsa"
  assume_role_policy = var.irsa_assume_role_policy  # genera con jsonencode()
}

resource "aws_iam_role_policy_attachment" "alb_policy" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = var.alb_controller_policy_arn
}