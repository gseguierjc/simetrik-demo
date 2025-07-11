
output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = data.aws_lb.grpc_alb.dns_name
}
