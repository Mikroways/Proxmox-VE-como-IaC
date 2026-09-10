# Provisioning de Proxmox VE (Ansible)

Segundo paso, después de `tofu apply`: la instancia sale del `apply` como
un Debian 13 limpio (solo SSH); este playbook la convierte en un nodo
Proxmox VE, usando el role community
[`lae.proxmox`](https://github.com/lae/ansible-role-proxmox) — pineado a
un tag fijo en `requirements.yml` (no es un role oficial de Proxmox, así
que no seguimos su rama principal a ciegas).

## Requisitos

- [`uv`](https://docs.astral.sh/uv/) (instala Ansible en un venv del
  proyecto — ver `pyproject.toml`/`uv.lock` en la raíz). Con `direnv
  allow` en la raíz del repo alcanza: el `.envrc` define un `layout_uv`
  (direnv todavía no trae `layout uv` en su stdlib) que corre `uv sync`
  solo y te deja `ansible-playbook` en el PATH.
- La infra ya aplicada (`tofu apply` corrido desde la raíz del repo) —
  el `apply` ya deja armado `ansible/inventory.yml` (ver `ansible.tf` en
  la raíz), no hace falta generarlo a mano

## Uso

```bash
# Desde la raiz del repo:

# 0. Si no usas direnv (o todavia no corriste `direnv allow`):
uv sync

# 1. Instalar el role pineado
ansible-galaxy install -r ansible/requirements.yml --force

# 2. Correr el playbook (el inventory ya lo genero `tofu apply`)
ansible-playbook -i ansible/inventory.yml ansible/playbook.yml
```

`pyproject.toml` pinea `ansible==14.4.0` y `uv.lock` fija el resto del
arbol de dependencias (misma lógica que `requirements.yml` para el role:
reproducible, no "lo que sea que resuelva pip hoy"). Para actualizar la
versión de Ansible: cambiar el pin en `pyproject.toml` y correr `uv lock`
de nuevo (regenera `uv.lock`; commitear el diff).

Si la instancia se reemplaza (cambia de IP), el próximo `tofu apply`
reescribe `ansible/inventory.yml` solo — no hay que tocarlo a mano.

Instalación completa: ~10-15 minutos, incluyendo el reboot intermedio que
el role dispara solo (`pve_reboot_on_kernel_update: true`).

## Qué hace

- `lae.proxmox`: agrega el repo `pve-no-subscription`, instala el kernel
  PVE, reinicia, instala `proxmox-ve` y dependencias, arregla
  `/etc/hosts` para que el hostname resuelva a la IP privada (lo necesita
  el cluster de Proxmox aunque sea de un solo nodo).
- Tareas propias del playbook: generan un password random para `root` y
  lo dejan en `/root/.proxmox-root-password` (0600) — necesario porque la
  UI web autentica por PAM/password, no por la key SSH de la instancia.

## Qué NO hace (a propósito)

- No crea el bridge `vmbr0` ni toca la red de la ENI. Automatizar eso es
  el paso más fácil de romper (se puede perder el acceso SSH a la
  instancia); queda manual para cuando decidas levantar VMs con
  networking propio. Ver [Network
  Configuration](https://pve.proxmox.com/wiki/Network_Configuration) en
  la doc oficial.

## Actualizar el pin del role

```bash
# Ver tags disponibles:
curl -s https://api.github.com/repos/lae/ansible-role-proxmox/tags | grep '"name"'
```

Editar `version:` en `requirements.yml` y volver a correr
`ansible-galaxy install -r ansible/requirements.yml --force`.
