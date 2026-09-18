# Template de VM (cloud image de Ubuntu 24.04)

Paso 3 del taller (después de tener los tokens del Paso 2). Construye el
template que va a clonar capmox para las VMs de Kubernetes: una cloud image
genérica de Ubuntu 24.04, con el agente QEMU instalado vía cloud-init.

El template es genérico — kubeadm/kubelet/containerd se instalan **en el boot de cada
VM real**, vía `preKubeadmCommands` (ver
[`../../clusterctl/cluster.yaml.sample`](../../clusterctl/cluster.yaml.sample)).
Cambiar la versión de k8s no requiere reconstruir ningún template,
solo editar el manifiesto de `clusterctl/`.

## Requisito: acceso SSH como root

El provider de Terraform necesita subir un snippet de cloud-init (el
`vendor-data` con la instalación de `qemu-guest-agent`) directamente al
nodo — el API de Proxmox no soporta subir este tipo de archivo vía token,
solo por SFTP. El playbook de Ansible del Paso 1 ya dejó la key pair de la
instancia autorizada también para `root` (ver `lab/ansible/playbook.yml`).
Antes de aplicar, cargar esa key en el agente SSH:

```bash
ssh-add $(cd ../.. && tofu output -raw private_key_path)
```

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu plan
tofu apply
```

Al terminar, queda un **template** `ubuntu-2404-k8s-base` en el nodo
`proxmox-lab`, con tag `ubuntu-24.04` — es lo que usa
`templateSelector.matchTags` en `../../clusterctl/cluster.yaml.sample`.
