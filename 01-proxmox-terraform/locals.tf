locals {
  credentials = yamldecode(file("${path.module}/credentials.yaml"))
  tokens_file = var.tokens_file
  capi_disk_storage_permissions = [for disk in var.capi_disk_storage :
    {
      path      = "/storage/${disk}"
      propagate = false
      role_id   = "PVEDatastoreUser"
      name      = "storage"
    }
  ]
  capi_cloud_init_storage_permissions = [for disk in var.capi_cloud_init_storage :
    {
      path      = "/storage/${disk}"
      propagate = false
      role_id   = "PVEDatastoreAdmin"
      name      = "cloudinit"
    }
  ]
  capi_user_permissions = { for c in toset(var.capi_clusters) :
    c => concat([
      {
        path      = "/"
        propagate = false
        role_id   = "PVEAuditor"
        name      = "audit"
      },
      {
        path      = "/nodes"
        propagate = true
        role_id   = "PVEAuditor"
        name      = "audit"
      },
      {
        path      = "/pool/${proxmox_virtual_environment_pool.capi-vm[c].pool_id}"
        propagate = false
        role_id   = "PVEVMAdmin"
        name      = "pool-adm"
      },
      {
        path      = "/pool/${proxmox_virtual_environment_pool.capi-template.pool_id}"
        propagate = false
        role_id   = "PVETemplateUser"
        name      = "pool-tpl"
      },
      {
        path      = var.clusterapi_sdn_path
        propagate = true
        role_id   = "PVESDNUser"
        name      = "net"
      }
      ],
      local.capi_disk_storage_permissions,
    local.capi_cloud_init_storage_permissions)
  }
  capi_token_permissions_list = flatten([
    for c, perms in local.capi_user_permissions : [
      for perm in perms :
      {
        key   = "${c}-${perm.name}-${perm.path}"
        value = { cluster = c, permission = perm }
      }
  ]])
  capi_token_permissions = { for item in local.capi_token_permissions_list :
    item.key => item.value
  }

}
