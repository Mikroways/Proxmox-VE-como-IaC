variable "region" {
  description = "Region de AWS donde se crea la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre base usado para taguear y nombrar los recursos"
  type        = string
  default     = "proxmox-over-ec2"
}

variable "environment" {
  description = "Tag de ambiente"
  type        = string
  default     = "lab"
}

variable "allowed_cidr_blocks" {
  description = <<-EOT
    Bloques CIDR autorizados a acceder por SSH (22/tcp) y a la UI web de
    Proxmox (8006/tcp). Sin default a proposito: hay que declararlo
    explicitamente en un .tfvars para evitar abrir el SG a 0.0.0.0/0 por
    descuido. Ejemplo: ["203.0.113.10/32"]
  EOT
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "Hay que declarar al menos un CIDR en allowed_cidr_blocks."
  }
}

variable "instance_type" {
  description = "Tipo de instancia EC2. Debe ser c8i/m8i/r8i (o variante flex) para soportar virtualizacion anidada en instancia virtual (no bare metal)."
  type        = string
  default     = "c8i.2xlarge"

  validation {
    condition     = can(regex("^(c8i|m8i|r8i)(-flex)?\\.", var.instance_type))
    error_message = "instance_type debe ser una familia c8i, m8i o r8i (o su variante flex): son las unicas que soportan nested virtualization fuera de instancias bare metal."
  }
}

variable "root_volume_size" {
  description = "Tamaño en GB del disco raiz (donde luego se instalaria Proxmox VE y sus VMs de prueba)"
  type        = number
  default     = 100
}

variable "ssh_user" {
  description = "Usuario SSH por defecto de la AMI (Debian usa 'admin')"
  type        = string
  default     = "admin"
}
