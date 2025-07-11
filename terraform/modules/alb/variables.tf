variable "region" {
  description = "AWS region"
  type        = string
}
variable "chart_version" {
  description = "chart_version"
  type        = string
  default = "1.13.0"
}

variable "sa_name" {
  description = "AWS region"
  type        = string
}

variable "grpc_host" {
  default = "grpc-demo-app.example.com"
}

variable "alb_policy_arn" {
  default = "arn:aws:iam::602401143452:policy/AWSLoadBalancerControllerIAMPolicy"
}

