variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "azs_map" {
  description = "Map of AZ to index for CIDR splitting"
  type        = map(number)
  default     = {"us-east-1a" = 0, "us-east-1b" = 1}
}


variable "grpc_port" {
  description = "Port for gRPC traffic"
  type        = number
  default     = 50051
}

variable "private_cidr_blocks" {
  description = "CIDR blocks allowed to access the gRPC port"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}