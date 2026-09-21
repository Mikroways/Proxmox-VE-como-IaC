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

resource "proxmox_virtual_environment_role" "imagebuilder" {
  role_id = "imagebuilder"

  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Pool.Allocate",
    "SDN.Audit",
    "SDN.Use",
    "Sys.AccessNetwork",
    "Sys.Audit",
    "VM.Allocate",
    "VM.Audit",
    "VM.Backup",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.CPU",
    "VM.Config.Cloudinit",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Console",
    "VM.GuestAgent.Audit",
    "VM.GuestAgent.FileRead",
    "VM.GuestAgent.FileSystemMgmt",
    "VM.GuestAgent.FileWrite",
    "VM.GuestAgent.Unrestricted",
    "VM.Migrate",
    "VM.PowerMgmt",
    "VM.Replicate",
    "VM.Snapshot",
    "VM.Snapshot.Rollback",
  ]
}
