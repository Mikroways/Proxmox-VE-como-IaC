terraform {
  backend "s3" {
    bucket = "nerdearla-workshop-097096559085-us-east-1-an"
    key    = "01-proxmox-terraform.tfstate"
    region = "us-east-1"
  }
}
