# Permisos en Proxmox con Terraform

Paso 1 del taller (después de tener Proxmox VE instalado — Paso 0, en
[`00-lab/`](../00-lab/)). Crea los usuarios de Proxmox (no del SO), roles,
tokens, pools y ACLs necesarios para trabajar después con Cluster API
(capmox) y el CSI de Proxmox.

## Qué crea

- **Roles**: `terraform-role`, `k8s-csi-datastore`, `k8s-csi-vm`, `imagebuilder`
  (este último con privilegios amplios sobre `/` — `Datastore.*`, `SDN.*`,
  `VM.*` — que es lo que pide `kubernetes-sigs/image-builder` para poder
  crear y convertir VMs en template).
- **Usuarios** (todos con token API): `terraform@pve`, `capi-management@pve`
  / `capi-tooling@pve` (uno por cada entrada de `capi_clusters`), `k8s-csi@pve`,
  `imagebuilder@pve` (lo consume `../04-image-builder`).
- **Pools**: `capi-management-vm`, `capi-tooling-vm` (uno por cada cluster, VMs
  aisladas entre clusters), `capi-template` (compartido, solo templates —
  lo usa `../02-vm-template`).
- **Permiso SDN**: generalizado a `/sdn/zones` (path raíz) — esta
  instalación no configura zonas SDN propias.

## Requisitos

- Proxmox VE instalado y funcional
  - Si no se cuenta con un proxmox, se puede usar el planteado en `00-lab/`
- Toolchain de la raíz del repo (`opentofu`, `direnv`) — ver
  `.tool-versions`.
- `direnv allow` corrido en la raíz del repo, con `PROXMOX_HOST_IP`/
  `PROXMOX_VE_PASSWORD` ya cargados en `.envrc.private` (ver
  "Conectarse" en `00-lab/README.md`) — `PROXMOX_VE_USERNAME`
  (`root@pam`) y el resto de las variables de conexión (`PROXMOX_VE_ENDPOINT`,
  `PROXMOX_VE_INSECURE`) salen solas de ahí.

## Antes de empezar

1. Completar `credentials.yaml.sample` con tus propios usuarios/passwords
   (los nombres de usuario pueden quedar igual, son solo convención):

   ```bash
   direnv allow   # primera vez, para que direnv cargue este .envrc
   cp credentials.yaml.sample credentials.yaml
   ```

   `credentials.yaml` queda agregado en el gitignore — nunca se commitea con valores
   reales.

## Uso

```bash
tofu init \
  -backend-config="bucket=<BUCKET_NAME>" \
  -backend-config="key=01-proxmox-terraform.tfstate" \
  -backend-config="region=us-east-1"
tofu plan
tofu apply
```

## Qué deja

Genera `tokens.yaml` (agregado en el gitignore, nunca se commitea) con un token de API
por usuario. De estos:

- `capi-management` y `capi-tooling` los consume `../03-cluster-api/` (uno
  por `ProxmoxCluster`, para aislar permisos entre clusters).
- `terraform` lo consume `../02-vm-template/` (pegado a mano en su
  propio `.envrc.private`, ver el README de ese directorio).
- `imagebuilder` lo consume `../04-image-builder/` (pegado a mano en su
  propio `.envrc.private`, ver el README de ese directorio).
- `k8s-csi` quedan generados y disponibles para cuando se instale el CSI driver

Para leer los tokens generados:

```bash
cat tokens.yaml
```

## Siguiente paso

El siguiente paso va a ser crear un template para ser usado como base para crear
los nodos de Kubernetes, el mismo se encuentra en [02-vm-template](../02-vm-template/README.md)