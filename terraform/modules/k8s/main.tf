data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-b4b053c1"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}


data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}


data "aws_security_group" "control_plane" {
  # Aquí usamos tu data.aws_eks_cluster.eks que ya existe
 id = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id

}


data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "tls_certificate" "eks_ca" {
  # Descarga el certificado TLS directamente del issuer OIDC
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}


resource "aws_iam_openid_connect_provider" "this" {
  # Usa la URL completa del issuer OIDC (incluye https://)
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_ca.certificates[0].sha1_fingerprint]
}

resource "aws_security_group_rule" "allow_cp_to_webhook" {
  description              = "Allow control plane  webhook 9443"
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.control_plane.id
  source_security_group_id = data.aws_security_group.control_plane.id
}


resource "kubernetes_namespace" "grpc_demo_server" {
  metadata {
    name = "grpc-demo-server"
  }
}

resource "kubernetes_namespace" "grpc_demo_client" {
  metadata {
    name = "grpc-demo-client"
  }
}

resource "kubernetes_deployment" "server" {
  metadata {
    name      = "service-server"
      namespace = kubernetes_namespace.grpc_demo_server.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "service-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "service-server"
        }
      }

      spec {
        container {
          name  = "service-server"
          image = "${data.terraform_remote_state.eks.outputs.ecr_repository_url}:server"
          image_pull_policy = "Always"
          port {
            container_port = 50051
          }
        }
      }
    }
  }
}


# resource "kubernetes_deployment" "client" {
#   metadata {
#     name      = "service-client"
#      namespace = kubernetes_namespace.grpc_demo_client.metadata[0].name
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         app = "service-client"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "service-client"
#         }
#       }

#       spec {
#         container {
#           name  = "service-client"
#           image = "${data.terraform_remote_state.eks.outputs.ecr_repository_url}:client"
#           image_pull_policy = "Always"
#           port {
#             container_port = 50051
#           }

#         #   volume_mount {
#         #     name       = "certs"
#         #     mount_path = "/app/certs"
#         #     read_only  = true
#         #   }
#         # }

#         # volume {
#         #   name = "certs"

#         #   secret {
#         #     secret_name = kubernetes_secret.grpc_certs.metadata[0].name
#         #   }
#         }
#       }
#     }
#   }
# }


resource "kubernetes_service" "service_server" {
  metadata {
    name      = "service-server"
    namespace = kubernetes_namespace.grpc_demo_server.metadata[0].name
    labels = {
      app = "service-server"
    }
  }

  spec {
    selector = {
      app = "service-server"
    }

    port {
      name        = "grpc"
      port        = 50051
      target_port = 50051
    }

     type     = "ClusterIP"     
  }
}

