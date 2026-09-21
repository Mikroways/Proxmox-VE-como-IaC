output "instance_public_ip" {
  description = "IP publica de la instancia"
  value       = module.ec2_proxmox.public_ip
}

output "proxmox_ui_url" {
  description = "URL de la UI web de Proxmox (una vez corrido ansible/playbook.yml)"
  value       = "https://${module.ec2_proxmox.public_ip}:8006"
}