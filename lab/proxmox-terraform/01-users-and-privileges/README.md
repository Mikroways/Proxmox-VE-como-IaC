# Permisos en Proxmox con Terraform

Paso 2 del taller (después de tener Proxmox VE instalado — Paso 1, en la raíz
de `lab/`). Crea los usuarios de Proxmox (no del SO), roles, tokens, pools y
ACLs necesarios para trabajar después con Cluster API (capmox) y el CSI de
Proxmox.

## Antes de empezar

Las credenciales `root@pam` contra la instancia (`PROXMOX_VE_USERNAME`/
`PROXMOX_VE_PASSWORD`) ya se calculan solas desde `lab/.envrc` — no hay que
setear nada a mano.

1. Completar `credentials.yaml.sample` con tus propios usuarios/passwords
   (los nombres de usuario pueden quedar igual, son solo convención):

   ```bash
   direnv allow
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

Esto genera `tokens.yaml` (gitignoreado, nunca se commitea) con los tokens
que va a consumir `../02-vm-template` y `../../clusterctl`.

## Qué crea

- **Roles**: `terraform-role`, `k8s-csi-datastore`, `k8s-csi-vm`.
- **Usuarios** (todos con token API): `terraform@pve`, `capi-management@pve`
  / `capi-tooling@pve` (uno por cada entrada de `capi_clusters`),
  `k8s-pve-exporter@pve` (solo `PVEAuditor`), `k8s-csi@pve`.
- **Pools**: `capi-management-vm`, `capi-tooling-vm` (uno por cluster, VMs
  aisladas entre clusters), `capi-template` (compartido, solo templates).
- **Permiso SDN**: generalizado a `/sdn/zones` (path raíz) — esta
  instalación no configura zonas SDN propias.