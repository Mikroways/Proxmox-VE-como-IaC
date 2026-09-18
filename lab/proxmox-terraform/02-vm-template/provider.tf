terraform {
  required_version = ">= 1.9.1"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78.1"
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
  #
  # El snippet de cloud-init (vendor-data) se sube por SFTP, no por API -
  # limitacion conocida del provider bpg para este content_type - por eso
  # hace falta tambien una conexion SSH como root al nodo (ver README.md).
  ssh {
    agent    = true
    username = "root"

    # El nodo no tiene una IP declarada en /etc/network/interfaces (la
    # interfaz queda "inet manual" - la IP real la asigna cloud-init/DHCP
    # por fuera de esa config), asi que el provider no puede autodetectarla
    # via el API de Proxmox ni resolverla por DNS. Se la damos explicita.
    node {
      name    = var.node_name
      address = var.proxmox_ssh_node_address
    }
  }
}
