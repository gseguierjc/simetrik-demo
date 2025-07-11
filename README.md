# gRPC & Terraform Demo Project

Este repositorio contiene dos partes principales:

1. **Demo gRPC en Python con TLS**
2. **Infraestructura AWS con Terraform**

---

## 🔎 Descripción

* **Parte Python gRPC**: Un servidor y un cliente que se comunican mediante gRPC sobre TLS, usando certificados auto-firmados en local y fácilmente reemplazables por certificados de AWS (ACM) en producción.
* **Parte Terraform**: Módulos que crean:

  * Una **VPC** con subredes públicas y privadas, NAT Gateway, rutas e IGW.
  * Un **Security Group** que permite tráfico gRPC.
  * Un **EKS Cluster** con repositorio ECR y pipeline de **CodeBuild** para CI/CD.

---

## 📂 Estructura de Carpetas

```
├── certs/                       # Certificados TLS (server.key, server.crt)
├── generated/                   # Archivos generados por `protoc`
│   └── saludo/
│       ├── saludo_pb2.py
│       └── saludo_pb2_grpc.py
├── protos/
│   └── saludo.proto            # Definición gRPC
├── server.py                    # Servidor gRPC con TLS
├── client.py                    # Cliente gRPC con TLS
├── buildspec.yml                # Especificación de build para CodeBuild
└── terraform/                   # Infraestructura Terraform
    ├── main.tf                  # Root configuration
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        ├── network/             # Módulo de red (VPC, subnets, SG)
        └── eks/                 # Módulo EKS (ECR, cluster, CI)
```

---

## ⚙️ Parte 1: Demo Python gRPC

### Prerrequisitos

* Python 3.8+ instalado (`py` en Windows o `python` en Unix).
* Librerías: `grpcio`, `grpcio-tools`.

### Pasos

1. **Generar certificados auto-firmados (solo local)**

   ```bash
   mkdir certs
   openssl req -x509 -newkey rsa:2048 -nodes \
     -keyout certs/server.key -out certs/server.crt \
     -days 365 -subj "/CN=localhost"
   ```

2. **Compilar el `.proto`**

   ```bash
   py -m grpc_tools.protoc -I=protos --python_out=generated --grpc_python_out=generated protos/saludo.proto
   ```

3. **Iniciar el servidor**

   ```bash
   py server.py
   ```

4. **Ejecutar el cliente**

   ```bash
   py client.py
   ```

> La comunicación se realizará en `localhost:50051` sobre TLS.

---

## 🏗️ Parte 2: Infraestructura con Terraform

### Prerrequisitos

* Terraform v1.0+ instalado en tu `PATH`.
* Credenciales AWS configuradas (`~/.aws/credentials` o variables de entorno).

### Inicialización

```bash
cd terraform
terraform init
```

### Validación y despliegue

```bash
terraform validate   # Comprueba sintaxis y referencias
terraform plan       # Muestra plan de cambios
terraform apply      # Despliega en AWS
```

---

## 🗂️ Módulos Terraform

### Módulo `network`

* **Crea**: VPC, subnets públicas/privadas, IGW, NAT Gateway, tablas de ruta.
* **Genera**: Security Group para permitir tráfico en el puerto gRPC.
* **Outputs**: `vpc_id`, `public_subnets`, `private_subnets`, `grpc_security_group_id`.

### Módulo `eks`

* **Crea**: Repositorio ECR, cluster EKS (terraform-aws-modules/eks), IAM Role para ALB Ingress.
* **CI/CD**: AWS CodeBuild para construir y pushear imágenes Docker a ECR.
* **Outputs**: `cluster_endpoint`, `cluster_id`, `ecr_repository_url`, `codebuild_project_arn`.

---

## 🔄 Validación Local de Terraform

* `terraform fmt` → formatea el código.
* `terraform validate` → valida sintaxis.
* `terraform plan` → simula despliegue.
* `terraform console` → evalúa expresiones.

Para pruebas de integración local puedes usar **LocalStack**.

---

## 📖 Referencias

* [gRPC Python Quickstart](https://grpc.io/docs/languages/python/quickstart/)
* [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
* [terraform-aws-modules/eks/aws](https://github.com/terraform-aws-modules/terraform-aws-eks)

---

*¡Listo para probar y desplegar!* 🎉
