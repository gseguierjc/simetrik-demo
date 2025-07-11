variable "acl" {
    description = "La política de control de acceso (ACL) para el bucket S3."
    type        = string
    default     = "private"
}

variable "versioning" {
    description = "Habilita o deshabilita el versionado en el bucket S3."
    type        = bool
    default     = false
}

variable "tags" {
    description = "Etiquetas para aplicar al bucket S3."
    type        = map(string)
    default     = {}
}

variable "force_destroy" {
    description = "Indica si se debe forzar la destrucción del bucket incluso si contiene objetos."
    type        = bool
    default     = false
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "state_bucket_name" {
    description = "El nombre del bucket S3 para almacenar el estado de Terraform."
    type        = string
}