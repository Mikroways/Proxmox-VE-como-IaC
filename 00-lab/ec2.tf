################################################################################
# AMI base: Debian 13 (Trixie), base recomendada para instalar Proxmox VE 9
################################################################################

data "aws_ami" "debian_13" {
  most_recent = true
  owners      = ["136693071363"] # Debian (cuenta oficial del Debian Cloud Team)

  filter {
    name   = "name"
    values = ["debian-13-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

################################################################################
# Instancia EC2
################################################################################

module "ec2_proxmox" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.4"

  name = "${local.name}-node"
  ami  = data.aws_ami.debian_13.id

  instance_type = var.instance_type
  key_name      = module.key_pair.key_pair_name

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.sg_proxmox.id]
  associate_public_ip_address = true
  create_security_group       = false

  # Proxmox VE NO se instala via user_data: la instancia sale "limpia"
  # (solo el Debian base + SSH). La instalacion la hace el playbook de
  # Ansible en ansible/ como segundo paso, despues del apply. Ver
  # ansible/README.md.

  # Habilita virtualizacion anidada en una instancia VIRTUAL (no bare metal).
  # Soportado solo en c8i / m8i / r8i (y sus variantes flex) - ver variable
  # "instance_type". Es lo que permite que Proxmox levante VMs con KVM.
  cpu_options = {
    nested_virtualization = "enabled"
  }

  # enable_volume_tags (default true en el modulo) es incompatible con
  # tags dentro de root_block_device - el provider de AWS rechaza el plan
  # si estan los dos a la vez ("Conflicting configuration arguments").
  enable_volume_tags = false

  root_block_device = {
    type                  = "gp3"
    size                  = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    tags = {
      Name = "${local.name}-node-root"
    }
  }

  metadata_options = {
    http_tokens = "required" # IMDSv2 obligatorio
  }

  monitoring = true

  tags = local.tags
}
