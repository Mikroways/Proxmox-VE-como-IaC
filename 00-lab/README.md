# proxmox-over-ec2

Infraestructura como código (OpenTofu) para levantar una instancia EC2 en
AWS pensada como base para instalar **Proxmox VE** en un laboratorio. Usa
familias de instancia (`c8i` por defecto) que soportan **virtualización
anidada** sin necesidad de instancias bare metal, así que Proxmox puede
levantar VMs con KVM aceleradas por hardware.

> Dos pasos: `tofu apply` levanta la infra (instancia Debian 13 limpia,
> red, SG, key pair) y `ansible-playbook` instala Proxmox VE sobre ella.
> Se separó así a propósito para que este repo sirva de base de lab —
> ver [`ansible/README.md`](ansible/README.md) para el detalle y el
> porqué de usar Ansible en vez de `user_data`.

## Qué crea

- VPC nueva (1 AZ, subnet pública, sin NAT) — módulo `terraform-aws-modules/vpc/aws`
- Security Group con `22/tcp` (SSH) y `8006/tcp` (UI web de Proxmox)
  restringidos a los CIDR que definas — módulo `terraform-aws-modules/security-group/aws`
- Key pair EC2 generado por Terraform (clave RSA nueva, no se reutiliza
  ninguna existente) — módulo `terraform-aws-modules/key-pair/aws`
- Instancia EC2 `c8i.2xlarge` (Debian 13, sin Proxmox todavía) con
  `cpu_options.nested_virtualization = "enabled"` — módulo
  `terraform-aws-modules/ec2-instance/aws`
- `ansible/inventory.yml` (recurso `local_file`, ver `ansible.tf`), listo
  para el paso de Ansible sin generar nada a mano

Todo con `default_tags` (`Repository`, `Managed-By`, `Environment`) y
100% destruible con `tofu destroy`.

## Requisitos

- [asdf](https://asdf-vm.com/) con los plugins `opentofu`, `direnv` y
  `uv` (ver `.tool-versions`, en la raíz de `lab/`)
- [direnv](https://direnv.net/) (opcional pero recomendado) — con `direnv
  allow` te deja `ansible-playbook` en el PATH solo, ver más abajo
- Credenciales de AWS con permisos para crear VPC, EC2, IAM key pair, SG
  (ver [Política mínima para ejecutar la receta](#política-mínima-para-ejecutar-la-receta))
- Ansible (instalado vía `uv`, ver `ansible/README.md` — no hace falta
  instalarlo aparte)

## Política mínima para ejecutar la receta

[`iam/minimal-policy.json`](iam/minimal-policy.json) es una policy de IAM
lista para usar.

**Lo que NO necesita, y por qué vale la pena decirlo**:
- **Nada de `iam:*`**: el módulo de EC2 puede crear un IAM instance
  profile propio, pero acá está desactivado (`create_iam_instance_profile`
  nunca se pisa, default `false`). Nadie que corra este repo necesita
  poder tocar IAM.

**Alcance de `Resource`**: casi todas las acciones de EC2 usadas acá
(`Describe*`, `Create*`, `Authorize*Ingress/Egress`) no soportan scoping
a nivel de resource de forma útil — es una limitación conocida de la API
de EC2, no una decisión de diseño — así que la policy usa `"Resource":
"*"` en los statements de EC2. Si en algún momento se quiere endurecer
más, `ec2:RunInstances` sí admite condiciones por ARN de subnet/AMI/SG/key-pair,
pero agrega bastante complejidad para lo que vale un repo de lab.

**Límite honesto de este método**: es un análisis estático contra las
versiones de módulo pineadas hoy — si se bumpean las versiones en
`versions.tf`, el set de recursos puede cambiar y la policy debería
recalcularse. Para una verificación 100% empírica (capturar las llamadas
reales que hace un `apply`+`destroy` contra una cuenta real), este mismo
toolchain ya tiene [`iamlive`](https://github.com/iann0036/iamlive)
instalable vía `asdf plugin add iamlive` — corre como proxy/wrapper y
genera la policy a partir del tráfico real hacia la API de AWS.

## Uso

```bash
# 1. Instalar la version de tofu declarada en .tool-versions (raiz de lab/)
asdf install

# 2. Configurar el profile de AWS (AWS_PROFILE vive en ../.envrc, no aca -
# es compartido con el resto del taller)
$EDITOR ../.envrc
direnv allow       # de paso, esto ya arma el venv de Ansible via uv sync

# 3. Configurar variables (obligatorio: allowed_cidr_blocks)
cp terraform.tfvars.example terraform.tfvars
curl -s https://checkip.amazonaws.com   # para saber tu IP publica
$EDITOR terraform.tfvars

# 4. Init / plan / apply (esto ya deja armado ansible/inventory.yml)
tofu init
tofu plan
tofu apply

# 5. Instalar Proxmox VE sobre la instancia ya creada
ansible-galaxy install -r ansible/requirements.yml --force
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml
```

Sin `direnv` (o si todavía no corriste `direnv allow`), el paso 5 necesita
`uv sync` antes de tener `ansible-playbook` disponible — ver
`ansible/README.md`.

Detalle del paso 5 (qué instala, qué no, cómo actualizar el pin del role)
en [`ansible/README.md`](ansible/README.md).

## Conectarse

Los outputs de este módulo (`instance_public_ip`, `proxmox_root_password_command`)
son los que el `.envrc` de la raíz recalcula solo como `PROXMOX_HOST_IP`/
`PROXMOX_URL`/`PROXMOX_VE_PASSWORD` para `01-proxmox-terraform`,
`02-vm-template`, `03-image-builder` y `04-clusterctl` — no hace falta copiarlos a mano a
ningún lado.

```bash
# Tofu ya deja el comando armado:
tofu output -raw ssh_command

# equivalente a:
ssh -i proxmox-over-ec2-key.pem admin@<ip-publica>
```

Una vez corrido el playbook, la UI de Proxmox queda en:

```bash
tofu output -raw proxmox_ui_url
```

La UI autentica `root` vía PAM con **password**, no con la key SSH. El
playbook genera uno random y lo deja en `/root/.proxmox-root-password`
(chmod 600) — recuperalo con:

```bash
tofu output -raw proxmox_root_password_command | sh
```

## Notas de seguridad

- La clave privada generada (`proxmox-over-ec2-key.pem`) queda en disco con
  permisos `0600` y **también en el `terraform.tfstate` en texto plano**
  (limitación del approach "Terraform genera la clave"). Para un lab con
  state local es un trade-off aceptable; si en algún momento se migra a
  backend remoto compartido, cifrar el backend (S3 + KMS, por ejemplo) o
  cambiar a `create_private_key = false` y traer una clave pública propia.
- `allowed_cidr_blocks` no tiene default: el `plan` falla si no lo
  definís, para evitar abrir el SG a `0.0.0.0/0` por accidente.
- `terraform.tfvars` y los `.pem` están en `.gitignore`: no se versionan.
- El password de root de Proxmox generado por `ansible/playbook.yml`
  queda en texto plano en `/root/.proxmox-root-password` dentro de la
  instancia (solo legible por root). No sale del disco ni se registra en
  el tfstate — para leerlo hace falta acceso SSH.
- `ansible/requirements.yml` pinea el role `lae.proxmox` a un tag fijo:
  es community (no oficial de Proxmox), así que no seguimos su rama
  principal a ciegas.

## Costo

`c8i.2xlarge` (8 vCPU / 16 GiB) tiene un costo por hora no trivial.
Recordá correr `tofu destroy` al terminar la prueba. Podés bajar el
tamaño con `instance_type` (debe seguir siendo familia `c8i`, `m8i` o
`r8i`, son las únicas con nested virtualization en instancia virtual).
