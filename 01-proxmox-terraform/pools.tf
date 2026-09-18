resource "proxmox_virtual_environment_pool" "capi-vm" {
  for_each = toset(var.capi_clusters)
  comment  = "ClusterAPI vms for ${each.key} managed by capmox"
  pool_id  = "${var.capi_vm_pool_prefix}${each.key}${var.capi_vm_pool_suffix}"
}

resource "proxmox_virtual_environment_pool" "capi-template" {
  comment = "ClusterAPI templates used by capmox"
  pool_id = var.capi_template_pool
}
