
resource "proxmox_virtual_environment_role" "imagebuilder" {
  role_id = "imagebuilder-role"
  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "SDN.Allocate",
    "SDN.Audit",
    "SDN.Use",
    "Sys.AccessNetwork",
    "Sys.Audit",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.Cloudinit",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.Monitor",
    "VM.Console",
    "VM.PowerMgmt"
  ]
}

resource "proxmox_virtual_environment_role" "iac" {
  role_id = "terraform-role"

  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Pool.Allocate",
    "Sys.Audit",
    "Sys.Console",
    "Sys.Modify",
    "SDN.Use",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.Cloudinit",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.PowerMgmt",
    "User.Modify"
  ]
}

resource "proxmox_virtual_environment_role" "k8s-csi-datastore" {
  role_id = "k8s-csi-datastore"

  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
  ]
}

resource "proxmox_virtual_environment_role" "k8s-csi-vm" {
  role_id = "k8s-csi-vm"

  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "VM.Allocate",
  ]
}
