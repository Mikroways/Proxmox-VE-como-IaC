# Template de VM (cloud image de Ubuntu 24.04)

Paso 2 del taller (después de correr `../01-proxmox-terraform`, que crea el
pool `capi-template` usado acá). Construye el template que va a clonar
capmox para las VMs de Kubernetes: una cloud image genérica de Ubuntu 24.04,
con el agente QEMU instalado vía cloud-init.

A diferencia del PoC original (que usaba Packer + `kubernetes-sigs/image-builder`
para hornear un template con kubeadm/kubelet ya instalados), acá el template
es genérico — kubeadm/kubelet/containerd se instalan **en el boot de cada
VM real**, vía `preKubeadmCommands` (ver
[`../04-clusterctl/cluster.yaml.sample`](../04-clusterctl/cluster.yaml.sample)).
Ventaja: cambiar la versión de k8s no requiere reconstruir ningún template,
solo editar el manifiesto de `04-clusterctl/`. `../03-image-builder/` ofrece
un camino alternativo: hornear esos mismos pasos en el template.

## Qué crea

- Un **template** de VM (nunca bootea) llamado `ubuntu-2404-k8s-base`, tag
  `ubuntu-24.04`, en el pool `capi-template` (creado por
  `../01-proxmox-terraform`).
- A partir de la cloud image oficial de Ubuntu 24.04 (`noble`), descargada
  directo al datastore del nodo.
- Sin `kubeadm`/`kubelet`/`containerd` ni `ip_config`/`vendor_data` propios
  — a propósito, para no pisar el cloud-init que capmox inyecta en cada
  clon real (ver el comentario en `main.tf`).

## Requisitos

- `../01-proxmox-terraform` ya aplicado — este módulo usa el pool
  `capi-template` que crea ese paso. **No** usa los tokens de
  `tokens.yaml`: se conecta como `root@pam`, heredado de `00-lab/` vía
  `.envrc` (`source_up`).
- Acceso SSH como root al nodo (ver más abajo).

### Acceso SSH como root

El provider de Terraform necesita subir un snippet de cloud-init (el
`vendor-data` con la instalación de `qemu-guest-agent`) directamente al
nodo — el API de Proxmox no soporta subir este tipo de archivo vía token,
solo por SFTP. El playbook de Ansible del Paso 0 ya dejó la key pair de la
instancia autorizada también para `root` (ver `00-lab/ansible/playbook.yml`).
Antes de aplicar, cargar esa key en el agente SSH:

```bash
ssh-add $(cd ../00-lab && tofu output -raw private_key_path)
```

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
tofu apply
```

## Qué deja

Un **template** `ubuntu-2404-k8s-base` en el nodo `proxmox-lab`, con tag
`ubuntu-24.04` — es lo que usa `templateSelector.matchTags` en
`../04-clusterctl/cluster.yaml.sample`.
