variable "alb_name" {
  description = "Load Balancer Name (truncado a 32 chars) creado por el Ingress/Controller"
  type        = string
}

variable "grpc_host" {
  description = "grpc_host"
  type        = string
}
