Proyecto Demo: Infraestructura EKS + gRPC Python con Terraform

Este repositorio proporciona una solución integral para desplegar y probar servicios gRPC en AWS EKS utilizando Terraform para la infraestructura y Python para la lógica de cliente-servidor. Está diseñado para equipos DevOps, SRE y desarrolladores que busquen una arquitectura modular, reutilizable y lista para producción, soportando seguridad (TLS), CI/CD y balanceo de carga con ALB.


Tabla de Contenidos

- Arquitectura General
- Estructura del Proyecto
- Requisitos Previos
- Despliegue: Orden, Dependencias y Flujo Recomendado
- Ejemplo de Output de Terraform
- Ejecución de la Demo gRPC (Python)
- Pruebas Funcionales y de Integración
- Extensión y Buenas Prácticas

Arquitectura General

[Python Client] <--TLS--> [AWS ALB - gRPC] <--TLS--> [EKS Cluster] <--gRPC--> [Python Server]
(infraestructura creada por Terraform)

- ALB (Application Load Balancer) público configurado para gRPC.
- EKS (Elastic Kubernetes Service) despliega los pods de la demo gRPC server.
- Recursos independientes: módulos de red, balanceo, almacenamiento y CI/CD.


Estructura del Proyecto

grpc_demo/
  ├─ client.py            # Cliente gRPC de prueba
  ├─ server.py            # Servidor gRPC
  ├─ generated/           # Códigos autogenerados por protoc
  └─ protos/              # Archivos .proto de contratos
  └─ certs/               # Certificados TLS de prueba

terraform/
  └─ modules/
       ├─ alb/            # Módulo ALB
       ├─ eks/            # Módulo EKS + submódulos
       ├─ network/        # Módulo red y subredes
       ├─ ci/             # Módulo CI/CD
       ├─ s3/             # Almacenamiento y backend
       └─ k8s/            # Configuración avanzada k8s

recursos_consolidados.txt  # Inventario automático de recursos (autogenerado)
README.md                  # Este archivo


Requisitos Previos

- AWS CLI (aws configure)
- Terraform >= 1.0
- Python >= 3.8
- kubectl
- Docker (opcional para pruebas locales)
- jq (para scripts auxiliares)
- Permisos de AWS para crear/modificar recursos (EKS, ALB, VPC, IAM, etc.)


Despliegue: Orden, Dependencias y Flujo Recomendado

Orden sugerido para desplegar infraestructura y servicios

1. Red (network)
   - Crea la VPC, subredes, gateways y recursos de red base.
   - Es fundamental, ya que todos los servicios AWS posteriores requieren esta capa.
2. Almacenamiento de estado (s3)
   - Si usas S3 como backend remoto de Terraform, este paso permite el manejo centralizado del estado y locking.
3. CI/CD (ci) (opcional, si implementas automatización)
   - Define pipelines que aplicarán los siguientes pasos automáticamente, útil para ambientes productivos.
4. Cluster Kubernetes (eks)
   - Implementa EKS, nodos administrados, IAM roles y configuraciones necesarias para levantar los pods.
   - Este paso depende de la VPC y a veces del almacenamiento para logs o controladores.
5. Balanceador (alb)
   - Despliega y configura el Application Load Balancer (ALB) apuntando al cluster EKS.
   - Puede requerir certificados TLS, que deben estar provisionados (manual o ACM).
6. Otros servicios (k8s, S3, recursos adicionales)
   - Despliega recursos complementarios según tus necesidades (almacenamiento, ingress, observabilidad, etc).

Ejemplo práctico de flujo de comandos

cd terraform/modules/network && terraform init && terraform apply -auto-approve
cd ../s3 && terraform init && terraform apply -auto-approve
cd ../eks && terraform init && terraform apply -auto-approve
cd ../alb && terraform init && terraform apply -auto-approve

Siempre revisa los outputs de cada módulo antes de avanzar, para inyectar valores (IDs, ARNs) en los siguientes módulos si fuera necesario.

Notas de dependencias
- Algunos módulos requieren outputs previos. Ejemplo: el módulo de EKS necesita IDs de subred y VPC.
- Si usas pipelines de CI, orquesta los pasos según esta secuencia en tu pipeline (GitHub Actions, GitLab CI, etc).


Ejemplo de Output de Terraform

Después del despliegue, obtendrás outputs como estos:

alb_dns_name = "my-grpc-alb-1234567890.us-east-1.elb.amazonaws.com"
eks_cluster_name = "demo-eks-grpc"
eks_kubeconfig = "...contenido base64..."
s3_bucket_name = "demo-eks-state-bucket-xxxx"

Puedes exportar el KUBECONFIG así:

terraform output -raw eks_kubeconfig > ~/.kube/config


Ejecución de la Demo gRPC (Python)

1. Instala dependencias

cd grpc_demo
pip install -r requirements.txt

(Si no tienes requirements.txt, instala manualmente:)
pip install grpcio grpcio-tools

2. Genera código gRPC (si editas los .proto)

python -m grpc_tools.protoc -I./protos --python_out=./generated --grpc_python_out=./generated ./protos/saludo/saludo.proto

3. Lanza el servidor (en local o en pod de EKS)

python server.py

4. Lanza el cliente

python client.py

Ejemplo de output esperado

Servidor:
[INFO] gRPC server started on port 50051 (TLS enabled)

Cliente:
[CLIENT] Enviando saludo...
[CLIENT] Respuesta recibida: ¡Hola, Jean!


Pruebas Funcionales y de Integración

1. Pruebas de Infraestructura

- Verifica la VPC y subredes
  - Usa el AWS Console o CLI para comprobar recursos creados correctamente.
- Verifica el cluster EKS
  - Ejecuta: aws eks list-clusters
  - Prueba acceso: kubectl get nodes (con el kubeconfig generado)
- Verifica el ALB
  - El output te dará el DNS del ALB. Chequea que esté activo en la consola de AWS.

2. Pruebas de Despliegue de Aplicación

- Despliega el server gRPC en EKS
  - Usa un manifiesto YAML de deployment y service apuntando a los pods de server.
  - Expón el servicio a través del Ingress o directamente por el ALB.

- Verifica logs del pod
  - kubectl logs <nombre-del-pod>
  - Debes ver mensajes como: [INFO] gRPC server started...

- Prueba conectividad interna
  - Usa port-forward temporal para probar con el cliente en local:
    kubectl port-forward service/<service-name> 50051:50051
    python client.py

3. Pruebas de Conectividad Externa y Seguridad

- Con el ALB
  - Actualiza el cliente gRPC para usar el DNS público del ALB.
  - Ejecuta: python client.py
  - Output esperado:
    [CLIENT] Enviando saludo...
    [CLIENT] Respuesta recibida: ¡Hola, Jean!

- Prueba TLS
  - Si usas certificados válidos, asegúrate de que la conexión sea segura (no warnings ni handshake errors).

4. Pruebas de Escalabilidad y Robustez

- Replica el server gRPC con más réplicas y prueba que las peticiones del cliente se distribuyen.
- Borra y recrea recursos críticos para validar que el pipeline y el Terraform pueden recrear la infraestructura.




