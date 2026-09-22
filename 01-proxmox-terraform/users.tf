################################################################################
# IaC user
################################################################################
resource "proxmox_virtual_environment_user" "terraform" {
  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.iac.role_id
  }

  comment  = "Terraform user for operations automation"
  password = local.credentials.users.terraform.password
  user_id  = local.credentials.users.terraform.username
}

################################################################################
# Cluster API user and token
################################################################################

resource "proxmox_virtual_environment_user" "clusterapi" {
  for_each = toset(var.capi_clusters)
  comment  = "ClusterAPI user for k8s management"
  user_id  = local.credentials.users.capi[each.key].username
  password = local.credentials.users.capi[each.key].password
  dynamic "acl" {
    for_each = local.capi_user_permissions[each.key]
    content {
      path      = acl.value["path"]
      propagate = acl.value["propagate"]
      role_id   = acl.value["role_id"]
    }
  }
}

resource "proxmox_user_token" "clusterapi_token" {
  for_each   = toset(var.capi_clusters)
  comment    = "Cluster ${each.key} API token"
  token_name = "capi"
  user_id    = proxmox_virtual_environment_user.clusterapi[each.key].user_id
}

resource "proxmox_acl" "clusterapi_token_permission" {
  for_each = local.capi_token_permissions
  token_id = proxmox_user_token.clusterapi_token[each.value.cluster].id

  role_id   = each.value.permission.role_id
  path      = each.value.permission.path
  propagate = each.value.permission.propagate
}

################################################################################
# CSI user and token
################################################################################

resource "proxmox_virtual_environment_user" "k8s-csi" {
  comment  = "kubernetes csi user for attach proxmox disks to vms"
  user_id  = local.credentials.users["k8s-csi"].username
  password = local.credentials.users["k8s-csi"].password
  dynamic "acl" {
    for_each = local.capi_disk_storage_permissions
    content {
      path      = acl.value.path
      propagate = false
      role_id   = proxmox_virtual_environment_role.k8s-csi-datastore.id
    }
  }

  acl {
    path      = "/pool"
    propagate = true
    role_id   = proxmox_virtual_environment_role.k8s-csi-vm.id
  }
}

resource "proxmox_user_token" "k8s-csi_token" {
  comment    = "k8s csi token"
  token_name = "k8s-csi"
  user_id    = proxmox_virtual_environment_user.k8s-csi.user_id
}

resource "proxmox_acl" "k8s-csi_token_permission-datastore" {
  for_each = { for i in local.capi_disk_storage_permissions : i.path => i }
  token_id = proxmox_user_token.k8s-csi_token.id

  role_id   = proxmox_virtual_environment_role.k8s-csi-datastore.id
  path      = each.key
  propagate = false
}

resource "proxmox_acl" "k8s-csi_token_permission-vm" {
  token_id = proxmox_user_token.k8s-csi_token.id

  role_id   = proxmox_virtual_environment_role.k8s-csi-vm.id
  path      = "/pool"
  propagate = true
}

################################################################################
# image-builder user and token
################################################################################
resource "proxmox_virtual_environment_user" "imagebuilder" {
  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.imagebuilder.role_id
  }

  comment  = "image-builder (Packer) user for baking VM templates"
  user_id  = local.credentials.users.imagebuilder.username
  password = local.credentials.users.imagebuilder.password
}

resource "proxmox_user_token" "imagebuilder_token" {
  comment    = "image-builder API token"
  token_name = "imagebuilder"
  user_id    = proxmox_virtual_environment_user.imagebuilder.user_id
}

resource "proxmox_acl" "imagebuilder_token" {
  token_id = proxmox_user_token.imagebuilder_token.id

  path      = "/"
  propagate = true
  role_id   = proxmox_virtual_environment_role.imagebuilder.role_id
}
