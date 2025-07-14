variable "region" {
  description = "AWS region"
  type        = string
}
variable "chart_version" {
  description = "chart_version"
  type        = string
  default = "1.13.3"
}

variable "sa_name" {
  description = "AWS "
  type        = string
}

variable "grpc_host" {
  description = "Dominio público para exponer el servicio gRPC"
  type        = string
}

variable "alb_policy_arn" {
  default = "arn:aws:iam::602401143452:policy/AWSLoadBalancerControllerIAMPolicy"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "restringe acceso público a tu IP"
  type        = list(string)
}


