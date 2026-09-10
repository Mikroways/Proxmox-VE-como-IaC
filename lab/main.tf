provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.project_name

  tags = {
    Repository  = "https://gitlab.com/mikroways/pruebas/proxmox-over-ec2"
    Managed-By  = "opentofu"
    Environment = var.environment
  }

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 1)
}

################################################################################
# Red
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = []

  # Sin NAT gateway: la instancia se accede via IP publica y no necesita
  # salida a internet a traves de una subnet privada.
  enable_nat_gateway = false

  manage_default_security_group = false

  tags = local.tags
}
