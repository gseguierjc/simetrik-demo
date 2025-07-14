output "alb_name" {
  description = "Truncated ALB name (clusterName-grpc subdomain) for lookup"
  value       = substr(
                  "${data.terraform_remote_state.eks.outputs.cluster_name}-${element(split(".", var.grpc_host), 0)}",
                  0,
                  32
                )
}

output "alb_dns_name" {
  description = "DNS público del ALB creado por el Ingress"
  value       = data.aws_lb.grpc_alb.dns_name
}

