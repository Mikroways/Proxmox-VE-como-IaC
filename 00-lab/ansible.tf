################################################################################
# Inventory de Ansible
################################################################################

# Se re-genera solo en cada `tofu apply` (no hace falta correr nada a
# mano): si la instancia se reemplaza y cambia de IP, el proximo apply
# reescribe el archivo. No es sensible (no contiene la clave privada, solo
# la ruta al .pem), asi que alcanza con local_file en vez de
# local_sensitive_file.
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/inventory.yml"

  content = templatefile("${path.module}/ansible/inventory.yml.tftpl", {
    instance_public_ip = module.ec2_proxmox.public_ip
    ssh_user           = var.ssh_user
    private_key_path   = local_sensitive_file.private_key.filename
  })

  file_permission = "0644"
}
