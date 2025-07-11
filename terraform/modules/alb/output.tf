output "alb_name" {
  description = "Truncated ALB name (clusterName-grpc subdomain) for lookup"
  value       = substr(
                  "${data.terraform_remote_state.eks.outputs.cluster_name}-${element(split(".", var.grpc_host), 0)}",
                  0,
                  32
                )
}

