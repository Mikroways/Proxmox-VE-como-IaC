# Proxmox VE como IaC

Taller práctico: de cero a un cluster de Kubernetes corriendo sobre **Proxmox VE**,
todo como código. Un camino secuencial de 4 pasos (`00` a `03`) más una alternativa
opcional (`04-image-builder`), cada uno en su propio directorio, cada uno con su
propio Terraform/OpenTofu state (o, en el caso de `04-image-builder`, su propio
build vía Docker/Packer) y su propio README con el paso a paso. Este README es el
mapa: qué construye cada paso, en qué orden corren, y qué necesitás tener instalado
antes de empezar.

> **Sobre la numeración**: `04-image-builder` tiene un número de directorio más
> alto que `03-cluster-api`, pero **no es un paso posterior** — es una alternativa
> a `02-vm-template` (los dos producen un template) y tiene que correr, si se usa,
> *antes* que `03-cluster-api`. Ver el diagrama.

Todo corre sobre una **única instancia EC2 en AWS** (no hace falta hardware propio):
la instancia soporta virtualización anidada, así que Proxmox puede levantar VMs con
KVM acelerado por hardware adentro de ella.

## Qué construye el taller

```
00-lab/               EC2 (Debian 13) + Ansible → nodo Proxmox VE
        │
        ▼
01-proxmox-terraform/ Usuarios, roles, tokens y pools en Proxmox
        │
        ├──▶ 02-vm-template/     Template genérico (cloud-init instala k8s en el boot)
        │
        └──▶ 04-image-builder/   (alternativo) Template con k8s pre-instalado, vía Packer
                       │
                       ▼
              03-cluster-api/     Cluster API (capmox) → clusters "management" y "tooling"
                                  corriendo como VMs reales sobre Proxmox
```

Cada paso consume lo que dejó el anterior (IP del nodo, tokens de API, template
de VM), así que hay que correrlos **en orden** la primera vez. `02-vm-template` y
`04-image-builder` son **alternativos entre sí**: los dos dejan un template que
`03-cluster-api` puede usar — alcanza con correr uno de los dos (ver la comparación
en [`04-image-builder/README.md`](04-image-builder/README.md)).

## Pasos

| Paso | Directorio | Qué hace | Detalle |
|---|---|---|---|
| 0 | [`00-lab/`](00-lab/) | Levanta la EC2 e instala Proxmox VE sobre ella (OpenTofu + Ansible) | [README](00-lab/README.md) |
| 1 | [`01-proxmox-terraform/`](01-proxmox-terraform/) | Crea usuarios/roles/tokens/pools de Proxmox para CAPI, CSI e image-builder | [README](01-proxmox-terraform/README.md) |
| 2 | [`02-vm-template/`](02-vm-template/) | Construye el template de VM que van a clonar los clusters | [README](02-vm-template/README.md) |
| 3 | [`03-cluster-api/`](03-cluster-api/) | `clusterctl` + capmox: crea los clusters `management` y `tooling` | [README](03-cluster-api/README.md) |

**Alternativa opcional** (en vez del paso 2, no además):

| Directorio | Qué hace | Detalle |
|---|---|---|
| [`04-image-builder/`](04-image-builder/) | Template con kubeadm/kubelet/containerd pre-instalados, vía Packer (Docker) | [README](04-image-builder/README.md) |

## Requisitos

- [asdf](https://asdf-vm.com/) con las versiones pineadas en [`.tool-versions`](.tool-versions):
  `opentofu`, `direnv`, `uv`, `clusterctl`, `kind`, `kubectl`, `krew`, `helm`.

  ```bash
  asdf plugin add opentofu
  asdf plugin add direnv
  asdf plugin add uv
  asdf plugin add clusterctl
  asdf plugin add kind
  asdf plugin add kubectl
  asdf plugin add krew
  asdf plugin add helm

  asdf install
  ```

- [direnv](https://direnv.net/) — el `.envrc` de la raíz centraliza las
  variables compartidas por todos los pasos (nodo/URL de Proxmox, venv de
  Python) y cada subdirectorio agrega las propias encima:

  ```bash
  direnv allow
  ```

  `PROXMOX_HOST_IP`/`PROXMOX_VE_PASSWORD` no se recalculan solos (ver
  ["Conectarse" en `00-lab/README.md`](00-lab/README.md#conectarse) — hay
  que pegarlos una vez en el `.envrc.private` de la raíz, agregado en el gitignore).
- (Opcional) Un bucket de S3 ya existente para el state remoto de `00-lab` y
  `01-proxmox-terraform` (ver [`backend.tf`](00-lab/backend.tf) en cada uno
  y "Cómo arrancar" más abajo) — no lo crea este repo. Se puede optar por contar
  con estados locales, entendiendo que debe encriptarse, ya que se crean datos
  sensibles.
- (Opcioanl) Credenciales de AWS (solo para el paso 0) con permisos para crear
  VPC, EC2, key pair y Security Group — ver [política mínima](00-lab/README.md#política-mínima-para-ejecutar-la-receta).
  Se puede optar por un Proxmox propio.
- Un agente SSH corriendo, para el paso 2 (sube un snippet de cloud-init por
  SSH a Proxmox) y para el túnel de red del paso 3.
- Solo si vas a usar `04-image-builder` en vez de `02-vm-template`: Docker
  (corre el image-builder empaquetado como contenedor) y una red con DHCP
  disponible para la VM builder — ver los requisitos propios en
  [`04-image-builder/README.md`](04-image-builder/README.md).

No hace falta instalar Ansible ni Python aparte: `direnv allow` en la raíz ya
deja `ansible-playbook` en el PATH vía `uv sync`.

## Cómo arrancar

Con `direnv allow` corrido en la raíz, cada paso es básicamente:

```bash
cd 0N-<paso>
cp terraform.tfvars.example terraform.tfvars   # completar antes de aplicar
direnv allow                                   # primera vez en el directorio
tofu init
tofu plan
tofu apply
```

`00-lab` y `01-proxmox-terraform` tienen un `backend.tf` con backend S3 vacío
(`backend "s3" {}`), así que su `tofu init` necesita los `-backend-config` con
tu bucket:

```bash
tofu init \
  -backend-config="bucket=<BUCKET_NAME>" \
  -backend-config="key=0N-<paso>.tfstate" \
  -backend-config="region=us-east-1"
```

El detalle específico de cada paso (variables obligatorias, comandos de
Ansible/kubectl/clusterctl, verificaciones) está en el README de su
directorio — arrancá por [`00-lab/README.md`](00-lab/README.md).

## Secretos y archivos generados

Nada de esto se sube a git (ver `.gitignore`): `terraform.tfvars`, `*.tfstate`,
`*.pem`, `.envrc.private`, `credentials.yaml`, `tokens.yaml`, kubeconfigs bajo
`.kube/`, y el `inventory.yml` de Ansible. Se generan localmente contra tu
propia instancia de AWS — cada persona que sigue el taller genera los suyos.

## Costo y limpieza

Todo es 100% destruible. La instancia EC2 (`c8i.2xlarge` por defecto) tiene un
costo por hora no trivial — al terminar:

```bash
# En orden inverso, desde 03-cluster-api/ hacia 00-lab/
kind delete cluster --name clusterctl   # si todavía existe
tofu destroy   # en 03, 02 (o el template de 04) y 01, del más nuevo al más viejo, hasta 00
```

`04-image-builder` no es Terraform/OpenTofu (es un wrapper de Docker/Packer):
el template que deja en Proxmox se borra a mano, desde la UI o `qm destroy
<vmid>` en el nodo.
