# Permisos en Proxmox con Terraform

Paso 1 del taller (después de tener Proxmox VE instalado — Paso 0, en
[`00-lab/`](../00-lab/)). Crea los usuarios de Proxmox (no del SO), roles,
tokens, pools y ACLs necesarios para trabajar después con Cluster API
(capmox) y el CSI de Proxmox.

## Qué crea

- **Roles**: `terraform-role`, `k8s-csi-datastore`, `k8s-csi-vm`.
- **Usuarios** (todos con token API): `terraform@pve`, `capi-management@pve`
  / `capi-tooling@pve` (uno por cada entrada de `capi_clusters`),
  `k8s-pve-exporter@pve` (solo `PVEAuditor`), `k8s-csi@pve`.
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
- `direnv allow` corrido en la raíz del repo: las credenciales `root@pam`
  contra la instancia (`PROXMOX_VE_USERNAME`/`PROXMOX_VE_PASSWORD`) ya se
  calculan solas desde `lab/.envrc` — no hay que setear nada a mano.

## Antes de empezar

1. Completar `credentials.yaml.sample` con tus propios usuarios/passwords
   (los nombres de usuario pueden quedar igual, son solo convención):

   ```bash
   direnv allow   # primera vez, para que direnv cargue este .envrc
   cp credentials.yaml.sample credentials.yaml
   ```

   `credentials.yaml` queda gitignoreado — nunca se commitea con valores
   reales.

2. Copiar `terraform.tfvars.example` a `terraform.tfvars` (gitignoreado):

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

## Uso

```bash
tofu init
tofu plan
tofu apply
```

## Qué deja

Genera `tokens.yaml` (gitignoreado, nunca se commitea) con un token de API
por usuario. De estos:

- `capi-management` y `capi-tooling` los consume `../04-clusterctl/` (uno
  por `ProxmoxCluster`, para aislar permisos entre clusters).
- `k8s-csi` y `pve_exporter` quedan generados y disponibles para cuando se
  instale el CSI driver o el exporter de Proxmox — está fuera del alcance
  de este repo.
- `terraform` no lo consume ningún paso siguiente.

`../02-vm-template` **no** consume `tokens.yaml` — usa las credenciales
`root@pam` heredadas de `00-lab/`. Lo que sí consume de este paso es el
pool `capi-template`.

Para leer los tokens generados:

```bash
cat tokens.yaml
```
