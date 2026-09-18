output "instance_id" {
  description = "ID de la instancia EC2"
  value       = module.ec2_proxmox.id
}

output "instance_public_ip" {
  description = "IP publica de la instancia"
  value       = module.ec2_proxmox.public_ip
}

output "instance_public_dns" {
  description = "DNS publico de la instancia"
  value       = module.ec2_proxmox.public_dns
}

output "security_group_id" {
  description = "ID del security group asociado a la instancia"
  value       = module.sg_proxmox.id
}

output "key_pair_name" {
  description = "Nombre del key pair creado en AWS"
  value       = module.key_pair.key_pair_name
}

output "private_key_path" {
  description = "Ruta local del archivo .pem con la clave privada"
  value       = local_sensitive_file.private_key.filename
}

output "ssh_user" {
  description = "Usuario SSH de la instancia (usado tambien por ansible/inventory.sh)"
  value       = var.ssh_user
}

output "ssh_command" {
  description = "Comando para conectarse por SSH a la instancia"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ${var.ssh_user}@${module.ec2_proxmox.public_ip}"
}

output "proxmox_ui_url" {
  description = "URL de la UI web de Proxmox (una vez corrido ansible/playbook.yml)"
  value       = "https://${module.ec2_proxmox.public_ip}:8006"
}

output "proxmox_root_password_command" {
  description = "Comando para recuperar el password de root generado por ansible/playbook.yml (usuario de login de la UI web)"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ${var.ssh_user}@${module.ec2_proxmox.public_ip} sudo cat /root/.proxmox-root-password"
}
