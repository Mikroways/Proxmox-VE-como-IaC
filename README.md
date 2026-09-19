# Proxmox VE como IaC

Taller práctico: de cero a un cluster de Kubernetes corriendo sobre **Proxmox VE**,
todo como código. Cinco pasos, cada uno en su propio directorio numerado, cada uno
con su propio Terraform/OpenTofu state (o, en el caso de `03-image-builder`, su
propio build de Packer) y su propio README con el detalle fino. Este README es el
mapa: qué construye cada paso, en qué orden corren, y qué necesitás tener instalado
antes de empezar.

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
        └──▶ 03-image-builder/   (alternativo) Template con k8s pre-instalado, vía Packer
                       │
                       ▼
              04-clusterctl/      Cluster API (capmox) → clusters "management" y "tooling"
                                  corriendo como VMs reales sobre Proxmox
```

Cada paso consume lo que dejó el anterior (IP del nodo, tokens de API, template
de VM), así que hay que correrlos **en orden** la primera vez. `02-vm-template` y
`03-image-builder` son **alternativos entre sí**: los dos dejan un template que
`04-clusterctl` puede usar — alcanza con correr uno de los dos (ver la comparación
en [`03-image-builder/README.md`](03-image-builder/README.md)).

## Pasos

| Paso | Directorio | Qué hace | Detalle |
|---|---|---|---|
| 0 | [`00-lab/`](00-lab/) | Levanta la EC2 e instala Proxmox VE sobre ella (OpenTofu + Ansible) | [README](00-lab/README.md) |
| 1 | [`01-proxmox-terraform/`](01-proxmox-terraform/) | Crea usuarios/roles/tokens/pools de Proxmox para CAPI y el CSI | [README](01-proxmox-terraform/README.md) |
| 2 | [`02-vm-template/`](02-vm-template/) | Construye el template de VM que van a clonar los clusters | [README](02-vm-template/README.md) |
| 3 | [`03-image-builder/`](03-image-builder/) | (opcional) template con kubeadm/kubelet/containerd pre-instalados vía Packer | [README](03-image-builder/README.md) |
| 4 | [`04-clusterctl/`](04-clusterctl/) | `clusterctl` + capmox: crea los clusters `management` y `tooling` | [README](04-clusterctl/README.md) |

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

- [direnv](https://direnv.net/) — el `.envrc` de la raíz calcula variables
  compartidas por los cuatro pasos (IP del nodo Proxmox, credenciales root,
  venv de Python) y cada subdirectorio agrega las propias encima:

  ```bash
  direnv allow
  ```

- Credenciales de AWS (solo para el paso 0) con permisos para crear VPC, EC2,
  key pair y Security Group — ver [política mínima](00-lab/README.md#política-mínima-para-ejecutar-la-receta).
- Un agente SSH corriendo, para el paso 2 (sube un snippet de cloud-init por
  SFTP a Proxmox) y para el túnel de red del paso 4.
- Solo si vas a usar `03-image-builder` en vez de `02-vm-template`: `packer`
  y una red con DHCP disponible para la VM builder — ver los requisitos
  propios en [`03-image-builder/README.md`](03-image-builder/README.md).

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
# En orden inverso, desde 04-clusterctl/ hacia 00-lab/
kind delete cluster --name clusterctl   # si todavía existe
tofu destroy   # en 04, 02 (o 03) y 01, del más nuevo al más viejo, hasta 00
```
