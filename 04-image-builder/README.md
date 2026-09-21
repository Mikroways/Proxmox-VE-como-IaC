# Template de VM con kubeadm/kubelet pre-instalados (image-builder)

Alternativa a [`../02-vm-template`](../02-vm-template/): en vez de un template
genérico que instala kubeadm/kubelet/containerd **en el boot de cada VM real**
(vía `preKubeadmCommands`), este directorio hornea esos mismos paquetes
**dentro del template**, usando la imagen Docker oficial de
[`kubernetes-sigs/image-builder`](https://github.com/kubernetes-sigs/image-builder)
(`registry.k8s.io/scl-image-builder/cluster-node-image-builder-amd64`), que
empaqueta su builder nativo de Proxmox (Packer + Ansible) sin necesidad de
clonar el repo ni instalar Packer a mano. Es el enfoque que usaba el PoC
original de este taller antes de simplificarse a `02-vm-template` (ver la nota
en `00-lab/README.md` y `02-vm-template/README.md`).

> **No es un paso posterior a `03-cluster-api`** a pesar de tener un número de
> directorio más alto — es una alternativa a `02-vm-template`, y como tal
> tiene que correr *antes* de `03-cluster-api` si se lo usa. Correr solo uno
> de los dos, no ambos.

## Por qué (vs. `02-vm-template`)

| | `02-vm-template` (genérico) | `04-image-builder` (pre-baked) |
|---|---|---|
| kubeadm/kubelet/containerd | se instalan en el boot de cada VM real (`preKubeadmCommands`) | ya están en el template |
| Cambiar versión de k8s | editar `03-cluster-api/cluster.yaml`, no toca el template | reconstruir el template completo |
| Boot de cada nodo real | más lento, depende de internet (baja paquetes en cada boot) | más rápido, no depende de internet en el boot |
| Para construir el template | solo Terraform/OpenTofu | Docker + una VM temporal con red propia (DHCP) |
| Gestión | Terraform (state, `tofu destroy`) | ninguna — es un `docker run` puntual, sin state |
| Permisos de Proxmox necesarios | acotados (ver `02-vm-template/provider.tf`) | amplios (rol `imagebuilder`: `Datastore.*`, `SDN.*`, `VM.*` en `/`) |

## Qué crea

- Un **template** de VM en el nodo `proxmox-lab`, con Ubuntu 24.04 y
  kubeadm/kubelet/containerd/`qemu-guest-agent` ya instalados — construido
  por el builder nativo de Proxmox de `kubernetes-sigs/image-builder`,
  corriendo dentro del contenedor `cluster-node-image-builder-amd64`.
- **El nombre/tag exacto del template los decide el propio builder de
  image-builder** (no está fijado por este repo) — verificalo en la UI/CLI de
  Proxmox después del build y usalo en `templateSelector.matchTags` de
  `../03-cluster-api/cluster.yaml.sample` si vas a usar este template en vez
  del de `02-vm-template` (que usa el tag `ubuntu-24.04`).
- **No queda en el pool `capi-template`** automáticamente (a diferencia de
  `02-vm-template`, que sí lo hace vía Terraform) — el build no tiene noción
  del pool de Proxmox, solo del datastore de disco (`PROXMOX_STORAGE_POOL`).
  Movelo al pool a mano si querés mantener la misma organización.

## Requisitos

- Docker, corriendo con `--net=host` (lo usa `build-image.sh`) — pensado para
  correr en Linux; en Docker Desktop (Mac/Windows) `--net=host` no funciona
  igual y no está probado acá.
- `../01-proxmox-terraform` ya aplicado — necesita el token `imagebuilder` de
  `tokens.yaml` (rol dedicado con privilegios amplios: `Datastore.*`, `SDN.*`,
  `Sys.AccessNetwork`, `VM.*` sobre `/`, muy por encima de lo que necesita
  `terraform-role` o los tokens de CAPI/CSI).
- `.envrc.private` de este directorio (agregado en el gitignore) con el token ya
  partido en sus dos partes:

  ```bash
  # tokens.yaml, clave "imagebuilder" -> token_value = "<token_id>=<secreto>"
  export PROXMOX_USERNAME="imagebuilder@pve!imagebuilder"   # antes del "="
  export PROXMOX_TOKEN="<secreto>"                          # despues del "="
  ```

- **Red con DHCP para la VM temporal del build** — el punto más importante
  de este entorno en particular: el builder levanta una VM intermedia que
  necesita una IP por DHCP en el bridge indicado (`PROXMOX_BRIDGE` en
  `environment-imagebuilder`, `vmbr0` acá). La red nested de este taller
  (`10.77.100.0/24`, ver `../03-cluster-api/README.md`) **no tiene DHCP a
  propósito** (por eso `03-cluster-api` usa `--ipam in-cluster`) — hay que
  resolver esto antes de poder correr un build (por ejemplo, un `dnsmasq`
  temporal en `vmbr0`, o apuntar `PROXMOX_BRIDGE` a una red que sí tenga DHCP).
- El storage de destino debe soportar el formato de disco elegido:
  `environment-imagebuilder` ya pide `disk_format=qcow2` sobre `local` (mismo
  datastore que usa `02-vm-template`). Con un backend por bloques (ej.
  `local-zfs`) habría que cambiar a `raw`.

## Cómo se usa

```bash
# 1. Elegir/confirmar la versión de k8s a instalar (opcional, ayuda a
# encontrar el paquete .deb exacto disponible para una serie X.Y):
./check-kubernetes-versions 1.36

# 2. Ajustar si hace falta las variables de k8s en .envrc (K8S_VERSION,
# K8S_RPM_VERSION, K8S_SERMVER, K8S_DEB_VERSION — el nombre "K8S_SERMVER"
# es así en el repo, no es un typo de este README) y las de
# environment-imagebuilder (PROXMOX_BRIDGE, PROXMOX_NODE, PROXMOX_STORAGE_POOL,
# PROXMOX_ISO_POOL, PACKER_FLAGS).
direnv allow

# 3. Correr el build (15-20 minutos en hardware estándar). El argumento es
# el target de Packer/Make dentro del contenedor; sin argumento imprime "help".
./build-image.sh build-proxmox-ubuntu-2404
```

`build-image.sh` hace un paso extra antes de invocar Packer: le pide a
**Proxmox** (no a Packer) que baje la ISO de instalación server-side vía su
API (`download-url`), en vez de dejar que el downloader de Packer
(`go-getter`) la baje él mismo — `go-getter` no sigue el redirect 308 que
devuelven `releases.ubuntu.com` y varios mirrors para pedidos con `Range`
header, lo que hace fallar la descarga si se usa `iso_url` directo (confirmado
en vivo contra este lab).

## Qué deja

- Un template en Proxmox con kubeadm/kubelet/containerd/`qemu-guest-agent` ya
  instalados, listo para que `../03-cluster-api` lo clone — sin depender de
  `preKubeadmCommands` para instalar paquetes en el boot de cada nodo real.
- A cambio, cambiar de versión de Kubernetes deja de ser "editar un YAML": hay
  que reconstruir el template (correr `build-image.sh` de nuevo) — el
  trade-off inverso al de `02-vm-template`.
- **No es un recurso de Terraform**: no hay `tofu destroy` para esto. Borrar
  el template es manual, desde la UI de Proxmox o `qm destroy <vmid>` en el
  nodo.
