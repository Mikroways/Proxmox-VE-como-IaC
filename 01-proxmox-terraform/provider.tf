terraform {
  required_version = ">= 1.9.1"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.114.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "proxmox" {
  # Usar variables de entorno para las credenciales:
  #   PROXMOX_VE_ENDPOINT
  #   PROXMOX_VE_USERNAME
  #   PROXMOX_VE_PASSWORD
  #   PROXMOX_VE_INSECURE
  #   PROXMOX_VE_TMPDIR
}
