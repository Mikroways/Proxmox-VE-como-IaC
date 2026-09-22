################################################################################
# Security Group
################################################################################

locals {
  sg_ports = {
    ssh         = { port = 22, description = "SSH" }
    proxmox_web = { port = 8006, description = "Proxmox VE web UI" }
  }

  # Combinacion CIDR x puerto -> una regla de ingress por cada par, ya que
  # el modulo v6 de security-group acepta un unico cidr_ipv4 por regla.
  sg_ingress_rules = {
    for pair in setproduct(keys(local.sg_ports), var.allowed_cidr_blocks) :
    "${pair[0]}-${replace(pair[1], "/", "_")}" => {
      cidr_ipv4   = pair[1]
      from_port   = local.sg_ports[pair[0]].port
      to_port     = local.sg_ports[pair[0]].port
      ip_protocol = "tcp"
      description = local.sg_ports[pair[0]].description
    }
  }
}

module "sg_proxmox" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = "${local.name}-sg"
  description = "SSH y UI web de Proxmox, restringido a IPs autorizadas"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = local.sg_ingress_rules

  egress_rules = {
    all = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
      description = "Todo el trafico saliente"
    }
  }

  tags = merge(local.tags, { Name = "${local.name}-sg" })
}
