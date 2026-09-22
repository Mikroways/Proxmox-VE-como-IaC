resource "proxmox_download_file" "cloud_image" {
  content_type = "iso"
  datastore_id = var.cloud_image_storage
  node_name    = var.node_name
  url          = var.cloud_image_url
}

resource "proxmox_virtual_environment_vm" "template" {
  name      = var.template_name
  node_name = var.node_name
  pool_id   = var.pool
  tags      = var.tags

  agent {
    enabled = true
  }
  cpu {
    cores = var.cpu_cores
  }
  memory {
    dedicated = var.memory
  }
  disk {
    file_id      = proxmox_download_file.cloud_image.id
    datastore_id = var.disk.datastore_id
    interface    = var.disk.interface
    size         = var.disk.size
  }
  # Sin bloque `initialization`, a proposito: cualquier ip_config/vendor_data
  # puesto aca queda grabado en la config de la VM y se HEREDA en cada clon
  # real que crea capmox, compitiendo con el cloud-init propio que capmox le
  # inyecta a cada clon (con la IP estatica real, el script de instalacion de
  # k8s, etc.) - y gana el de Proxmox, no el de capmox, dejando los nodos
  # reales sin red (pedian IP por DHCP, que no existe en esta red) y sin
  # kubeadm instalado. El template en si nunca se arranca (template=true lo
  # crea directo, sin bootear), asi que tampoco hacia falta este bloque para
  # instalar nada en el template - qemu-guest-agent se instala en el boot de
  # cada VM real (ver capi-install-k8s.sh en clusterctl/), no aca.
  network_device {
    bridge = var.network_bridge
  }
  template = true
}
