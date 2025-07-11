resource "aws_iam_user" "eks_demo" {
  name = "eks-demo"
  path = "/system/"
}

resource "aws_iam_user_policy_attachment" "eks_demo_attach" {
  user       = aws_iam_user.eks_demo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
