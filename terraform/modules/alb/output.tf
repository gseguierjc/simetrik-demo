
output "alb_dns_name" {
  description = "DNS público del ALB"
  value       = kubernetes_ingress_v1.grpc_ingress.status[0].load_balancer[0].ingress[0].hostname
}