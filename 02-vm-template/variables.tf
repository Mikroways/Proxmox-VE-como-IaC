variable "node_name" {
  type    = string
  default = "proxmox-lab"
}

variable "proxmox_ssh_node_address" {
  type        = string
  description = "IP/hostname para la conexion SSH al nodo (ver provider.tf) - el nodo no tiene una IP declarada en su config de red, asi que el provider no puede autodetectarla."
}

variable "template_name" {
  type    = string
  default = "ubuntu-2404-k8s-base"
}

variable "tags" {
  type    = list(string)
  default = ["ubuntu-24.04"]
}

variable "pool" {
  type    = string
  default = "capi-template"
}

variable "cloud_image_storage" {
  type    = string
  default = "local"
}

variable "cloud_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "disk" {
  type = object({
    interface    = optional(string, "scsi0")
    size         = number
    datastore_id = string
  })
}
