# Template de VM con kubeadm/kubelet pre-instalados (image-builder)

> **Estado: propuesto, todavía no implementado.** Este directorio está vacío
> hoy — este README documenta el enfoque para implementarlo (Packer +
> [`kubernetes-sigs/image-builder`](https://github.com/kubernetes-sigs/image-builder)),
> no un paso ya probado como el resto del taller. La sección
> ["Qué falta"](#qué-falta-para-implementarlo) lista el trabajo pendiente.

Paso **alternativo** a [`../02-vm-template`](../02-vm-template/): en vez de un
template genérico que instala kubeadm/kubelet/containerd **en el boot de cada
VM real** (vía `preKubeadmCommands`), este paso hornea esos mismos paquetes
**dentro del template**, usando el builder nativo de Proxmox de
`kubernetes-sigs/image-builder` (Packer + Ansible). Es el enfoque que usaba el
PoC original de este taller antes de simplificarse a `02-vm-template` (ver la
nota en `00-lab/README.md` y `02-vm-template/README.md`).

## Por qué (vs. `02-vm-template`)

| | `02-vm-template` (genérico) | `03-image-builder` (pre-baked) |
|---|---|---|
| kubeadm/kubelet/containerd | se instalan en el boot de cada VM real (`preKubeadmCommands`) | ya están en el template |
| Cambiar versión de k8s | editar `04-clusterctl/cluster.yaml`, no toca el template | reconstruir el template completo |
| Boot de cada nodo real | más lento, depende de internet (baja paquetes en cada boot) | más rápido, no depende de internet en el boot |
| Para construir el template | solo Terraform/OpenTofu | Packer + Ansible + una VM temporal con red propia |
| Permisos de Proxmox necesarios | acotados (ver `provider.tf`) | amplios (`Datastore.*`, `SDN.*`, `VM.*` en `/`) |

Ninguno es "mejor" en general — es un trade-off entre velocidad/reproducibilidad
de boot y complejidad de build. `04-clusterctl` puede usar el template de
cualquiera de los dos: solo cambia a qué `templateSelector.matchTags` apunta.

## Qué va a crear

- Un **template** de VM en el nodo `proxmox-lab`, con Ubuntu 24.04 y
  kubeadm/kubelet/containerd/`qemu-guest-agent` ya instalados — construido
  con `make build-proxmox-ubuntu-2404` desde `images/capi` del repo
  `kubernetes-sigs/image-builder` (tiene un builder Packer nativo para
  Proxmox, no hace falta el builder `raw`/genérico).
- Vive en el mismo pool `capi-template` que usa `02-vm-template` (creado por
  `../01-proxmox-terraform`), con un tag distinto (propuesto:
  `ubuntu-24.04-baked`) para que `04-clusterctl/cluster.yaml` pueda elegir
  entre uno y otro template vía `templateSelector.matchTags`.

## Requisitos

- [Packer](https://developer.hashicorp.com/packer) — `kubernetes-sigs/image-builder`
  puede instalarlo solo en `images/capi/.bin` vía `make deps-proxmox`, no hace
  falta agregarlo a `.tool-versions` si se usa así.
- Clonar `kubernetes-sigs/image-builder` (dependencia externa, no vendoreada
  en este repo — ver ["Qué falta"](#qué-falta-para-implementarlo)).
- `../01-proxmox-terraform` ya aplicado — **pero con un usuario/token nuevo
  que hoy no existe** (ver más abajo): los tokens que ese paso ya crea
  (`terraform`, `capi-*`, `k8s-csi`, `pve-exporter`) tienen permisos acotados
  a lo que necesita cada uno, y ninguno alcanza para que Packer cree y
  convierta VMs en template. El builder de Proxmox de image-builder necesita
  un usuario con, como mínimo, `Datastore.*`, `SDN.*`, `Sys.AccessNetwork`,
  `Sys.Audit` y `VM.*` sobre el path `/` — la documentación oficial de
  image-builder recomienda un rol dedicado en vez de reusar uno existente.
- **Red con DHCP para la VM temporal del build** — este es el gotcha más
  importante en este entorno particular: el builder de Packer levanta una VM
  intermedia que necesita una IP por DHCP en el bridge que se le indique
  (`PROXMOX_BRIDGE`, típicamente `vmbr0`). La red nested de este taller
  (`10.77.100.0/24`, ver `../04-clusterctl/README.md`) **no tiene DHCP a
  propósito** — por eso `04-clusterctl` usa `--ipam in-cluster` en vez de un
  servidor DHCP. Antes de poder correr un build acá hay que resolver esto:
  por ejemplo, un `dnsmasq` temporal escuchando en `vmbr0` durante el build,
  o un bridge/VLAN separado que sí tenga DHCP (la propia subnet de la VPC de
  `00-lab/`, si `vmbr0` llegara a estar bridgeado a la ENI, es una opción con
  DHCP real de AWS).
- El storage de destino debe soportar el formato de disco elegido: `local`
  (el datastore que ya usa `02-vm-template`) acepta `qcow2` (default) sin
  cambios. Si en algún momento se usara `local-zfs` u otro backend por
  bloques, hay que forzar `-var disk_format=raw` (ZFS no soporta `qcow2`).

## Cómo se encara (pasos propuestos)

```bash
# 1. Clonar image-builder (fuera de este repo, o como submódulo — a definir)
git clone https://github.com/kubernetes-sigs/image-builder.git
cd image-builder/images/capi
make deps-proxmox

# 2. Credenciales y config de Proxmox para Packer (usuario/token todavía
# por crear en 01-proxmox-terraform, ver "Qué falta")
export PROXMOX_URL="https://${PROXMOX_HOST_IP}:8006/api2/json"   # OJO: sufijo
# /api2/json distinto del PROXMOX_URL que ya define el .envrc de la raíz —
# no pisarlo, exportarlo solo en este shell/paso.
export PROXMOX_USERNAME="image-builder@pve!capi"                # <user>@<realm>!<token_id>
export PROXMOX_TOKEN="<secreto del token>"
export PROXMOX_NODE="$PROXMOX_NODE_NAME"
export PROXMOX_STORAGE_POOL="local"
export PROXMOX_BRIDGE="vmbr0"

# 3. Build (15-20 minutos en hardware estándar)
make build-proxmox-ubuntu-2404

# 4. Verificar que el template quedó en Proxmox, y taguearlo/moverlo al
# pool capi-template si el builder no lo dejó ahí directo
```

## Qué va a dejar

- Un template listo para que `04-clusterctl` lo clone directo, sin depender
  de `preKubeadmCommands` para instalar paquetes — arranque de nodo real más
  rápido y sin depender de internet en ese momento.
- A cambio, cambiar de versión de Kubernetes deja de ser "editar un YAML": hay
  que reconstruir el template (`make build-proxmox-ubuntu-2404` de nuevo) —
  el trade-off inverso al de `02-vm-template`.

## Qué falta para implementarlo

- [ ] Agregar un rol + usuario + token `image-builder` en
      `../01-proxmox-terraform/roles.tf` y `users.tf`, con los privilegios
      mínimos que pide image-builder (ver "Requisitos").
- [ ] Decidir cómo resolver el DHCP para la VM de build en `vmbr0` (dnsmasq
      temporal vs. bridge separado) y documentarlo acá.
- [ ] Decidir cómo se trae `kubernetes-sigs/image-builder` a este repo (clone
      manual gitignoreado, submódulo, o un `Makefile`/script propio en este
      directorio que lo automatice) y versionar el archivo de variables de
      Packer (equivalente al `terraform.tfvars.example` del resto de pasos).
- [ ] Elegir el tag distintivo del template pre-baked (propuesto:
      `ubuntu-24.04-baked`) y agregar un `cluster.yaml.sample` (o una
      variante) en `../04-clusterctl/` que lo use.
