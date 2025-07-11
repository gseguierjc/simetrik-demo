variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "node_instance_type" {
  description = "Tipo de instancia EC2 para los nodos de EKS "
  type        = string
  default     = "t2.medium"
}

variable "desired_capacity" {
  description = "capacidad deseada de nodos EKS"
  type        = number
  default     = 1 
}

variable "max_capacity" {
  description = "capacidad maxima deseada de nodos EKS"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "capacidad minima deseada de nodos EKS"
  type        = number
  default     = 1
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "restringe acceso público a tu IP"
  type        = list(string)
}


