provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_ca_certificate)
  token                  = data.terraform_remote_state.eks.outputs.cluster_auth_token
}


data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "demo-eks-state-bucket-647187952873-7632948f"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
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

        #   volume_mount {
        #     name       = "certs"
        #     mount_path = "/app/certs"
        #     read_only  = true
        #   }
        # }

        # volume {
        #   name = "certs"

        #   secret {
        #     secret_name = kubernetes_secret.grpc_certs.metadata[0].name
        #   }
        }
      }
    }
  }
}


resource "kubernetes_deployment" "client" {
  metadata {
    name      = "service-client"
     namespace = kubernetes_namespace.grpc_demo_client.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "service-client"
      }
    }

    template {
      metadata {
        labels = {
          app = "service-client"
        }
      }

      spec {
        container {
          name  = "service-client"
          image = "${data.terraform_remote_state.eks.outputs.ecr_repository_url}:client"
          image_pull_policy = "Always"
          port {
            container_port = 50051
          }

        #   volume_mount {
        #     name       = "certs"
        #     mount_path = "/app/certs"
        #     read_only  = true
        #   }
        # }

        # volume {
        #   name = "certs"

        #   secret {
        #     secret_name = kubernetes_secret.grpc_certs.metadata[0].name
        #   }
        }
      }
    }
  }
}


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

    type = "LoadBalancer"
  }
}

