################################################################################
# Key Pair (genera par publico/privado con tls_private_key internamente)
################################################################################

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "~> 3.0"

  key_name           = "${local.name}-key"
  create_private_key = true

  tags = local.tags
}

# Vuelca la clave privada generada a un archivo local para poder hacer
# `ssh -i` directamente. Queda tambien en el tfstate en texto plano: para
# un lab con state local es aceptable, pero no versionar el .pem (ver
# .gitignore) ni usar este patron con state remoto compartido sin cifrar
# el backend.
resource "local_sensitive_file" "private_key" {
  # El modulo le hace trimspace() a la key antes de exponerla como output,
  # lo que le saca el newline final. OpenSSH/OpenSSL recientes (probado
  # con OpenSSH 10 + OpenSSL 3.5) son estrictos parseando el bloque PEM
  # "OPENSSH PRIVATE KEY" y fallan con "error in libcrypto" si al archivo
  # le falta ese newline al final - lo volvemos a agregar.
  content         = "${module.key_pair.private_key_openssh}\n"
  filename        = "${path.module}/${local.name}-key.pem"
  file_permission = "0600"
}
