# Proyecto Demo: Infraestructura EKS + gRPC Python con Terraform

Este repositorio proporciona una solución integral para desplegar y probar servicios gRPC en AWS EKS utilizando Terraform para la infraestructura y Python para la lógica de cliente-servidor. Está diseñado para equipos DevOps, SRE y desarrolladores que busquen una arquitectura modular, reutilizable y lista para producción, soportando seguridad (TLS), CI/CD y balanceo de carga con ALB.

## Tabla de Contenidos

- Arquitectura General
- Estructura del Proyecto
- Requisitos Previos
- Despliegue: Orden, Dependencias y Flujo Recomendado
- Ejemplo de Output de Terraform
- Ejecución de la Demo gRPC (Python)
- Pruebas Funcionales y de Integración
- Extensión y Buenas Prácticas

## Arquitectura General

La solución implementa un clúster EKS con balanceador ALB, almacenamiento remoto S3 para el estado de Terraform, y servicios gRPC en Python. Se incluyen módulos para CI/CD, IAM, red, y otros recursos complementarios.

## Estructura del Proyecto

```
├─ grpc_demo/       # Código Python de la demo gRPC
│   ├─ client.py
│   ├─ server.py
│   ├─ generated/   # Archivos generados (protobuf)
│   ├─ protos/      # Definiciones proto
├─ terraform/
│   ├─ modules/
│       ├─ network/        # Módulo red y subredes
│       ├─ ci/             # Módulo CI/CD
│       ├─ s3/             # Almacenamiento y backend
│       ├─ eks/            # Kubernetes EKS, nodos, IAM
│       ├─ alb/            # Application Load Balancer
│       └─ k8s/            # Configuración avanzada k8s
recursos_consolidados.txt  # Inventario automático de recursos (autogenerado)
README.md                  # Este archivo
```

## Requisitos Previos

- AWS CLI (`aws configure`)
- Terraform >= 1.0
- Python >= 3.8
- kubectl
- Docker (opcional para pruebas locales)
- jq (para scripts auxiliares)
- Permisos de AWS para crear/modificar recursos (EKS, ALB, VPC, IAM, etc.)

## Despliegue: Orden, Dependencias y Flujo Recomendado

Orden sugerido para desplegar infraestructura y servicios:

1. **Red (network)**  
   Crea la VPC, subredes, gateways y recursos de red base.  
   Es fundamental, ya que todos los servicios AWS posteriores requieren esta capa.
2. **Almacenamiento de estado (s3)**  
   Si usas S3 como backend remoto de Terraform, este paso permite el manejo centralizado del estado y locking.
3. **CI/CD (ci) (opcional, si implementas automatización)**  
   Define pipelines que aplicarán los siguientes pasos automáticamente, útil para ambientes productivos.
4. **Cluster Kubernetes (eks)**  
   Implementa EKS, nodos administrados, IAM roles y configuraciones necesarias para levantar los pods.  
   Este paso depende de la VPC y a veces del almacenamiento para logs o controladores.
5. **Balanceador (alb)**  
   Despliega y configura el Application Load Balancer (ALB) apuntando al cluster EKS.  
   Puede requerir certificados TLS, que deben estar provisionados (manual o ACM).
6. **Otros servicios (k8s, S3, recursos adicionales)**  
   Despliega recursos complementarios según tus necesidades (almacenamiento, ingress, observabilidad, etc).

### Ejemplo práctico de flujo de comandos

```sh
cd terraform/modules/network && terraform init && terraform apply -auto-approve
cd ../s3 && terraform init && terraform apply -auto-approve
cd ../eks && terraform init && terraform apply -auto-approve
cd ../alb && terraform init && terraform apply -auto-approve
```

Siempre revisa los outputs de cada módulo antes de avanzar, para inyectar valores (IDs, ARNs) en los siguientes módulos si fuera necesario.

### Notas de dependencias

- Algunos módulos requieren outputs previos. Ejemplo: el módulo de EKS necesita IDs de subred y VPC.
- Si usas pipelines de CI, orquesta los pasos según esta secuencia en tu pipeline (GitHub Actions, GitLab CI, etc).

## Ejemplo de Output de Terraform

Después del despliegue, obtendrás outputs como estos:
- IDs de VPC, subredes
- ARN de roles IAM
- Endpoint del clúster EKS
- DNS del ALB

## Ejecución de la Demo gRPC (Python)

1. Accede al directorio `grpc_demo`.
2. Instala dependencias con `pip install -r requirements.txt` (si aplica).
3. Ejecuta el servidor y cliente según la documentación de los scripts.

## Pruebas Funcionales y de Integración

- Realiza pruebas locales con Docker antes de subir a EKS.
- Usa pruebas de integración sobre el clúster para validar conectividad y seguridad.
- Borra y recrea recursos críticos para validar que el pipeline y el Terraform pueden recrear la infraestructura.

## Extensión y Buenas Prácticas

- Modulariza los recursos en Terraform para reusabilidad.
- Utiliza archivos de inventario (`recursos_consolidados.txt`) para monitorear el estado y cambios de la infraestructura.
- Mantén la documentación actualizada en los README de cada módulo.
- Revisa los docs y ejemplos incluidos en los submódulos Terraform para mejores prácticas avanzadas.

---

**Referencias adicionales:**  
- Documentación y ejemplos en los archivos `README.md` de los submódulos Terraform.
- Inventario completo en `recursos_consolidados.txt` generado automáticamente.
