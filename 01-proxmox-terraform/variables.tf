# Path de ACL usado para el permiso PVESDNUser. El PoC original apuntaba
# a una zona SDN custom real ("localnetwork") que no existe en una
# instalacion Proxmox VE default (como la que deja lab/ en AWS). Se
# generaliza al path raiz de SDN Zones, valido en cualquier instalacion
# aunque no se configuren zonas custom.
variable "clusterapi_sdn_path" {
  type    = string
  default = "/sdn/zones"
}

variable "tokens_file" {
  type    = string
  default = "tokens.yaml"
}

variable "capi_clusters" {
  type        = list(string)
  description = "Clusters to create users for"
}

variable "capi_vm_pool_prefix" {
  type    = string
  default = "capi-"
}

variable "capi_vm_pool_suffix" {
  type    = string
  default = "-vm"
}

variable "capi_template_pool" {
  type    = string
  default = "capi-template"
}

variable "capi_cloud_init_storage" {
  type = list(string)
}

variable "capi_disk_storage" {
  type = list(string)
}
