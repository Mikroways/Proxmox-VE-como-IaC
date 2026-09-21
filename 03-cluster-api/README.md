# Instalación de un cluster con clusterctl

Paso 3 del taller: el último necesario para tener un cluster de Kubernetes
real corriendo sobre Proxmox. `clusterctl` define un flujo de vida completo
para clusters de Kubernetes: crear un cluster efímero (kind), instalar ahí
los controladores necesarios para un hipervisor/cloud dado, y desde ese
cluster inicializar clusters reales a partir de manifiestos.

> `../04-image-builder/` (número de directorio más alto, pero **no** un
> paso posterior a este) es una alternativa opcional a `../02-vm-template/`
> para el template que se clona acá — si la usás en vez de `02-vm-template`,
> actualizá `templateSelector.matchTags` en `cluster.yaml.sample` con el tag
> que haya quedado en ese template.

## Qué crea

- Un cluster `kind` local llamado `clusterctl`, efímero — solo se usa como
  bootstrap para correr los controladores de Cluster API y crear los
  clusters reales.
- Un cluster real `management` sobre Proxmox (namespace `management`), con
  Cilium como CNI y sin taint de control-plane — termina alojando él mismo
  los controladores de CAPI después del pivot.
- Un segundo cluster real `tooling` sobre Proxmox (namespace `tooling`),
  creado desde `management` una vez pivoteado.
- Las VMs reales de cada cluster, clonadas del template de
  `../02-vm-template` y aisladas por pool (`capi-management-vm`,
  `capi-tooling-vm`, creados por `../01-proxmox-terraform`).

## Requisitos

- Herramientas: `kind`, `kubectl`, `clusterctl`, `helm`, `envsubst`
  (paquete `gettext`) — ver `.tool-versions` en la raíz. Opcionalmente
  `sshuttle` si vas a correr `kind` fuera de la instancia EC2 (ver más
  abajo).
- `../01-proxmox-terraform` ya aplicado — hace falta `tokens.yaml` (tokens
  `capi-management`/`capi-tooling`).
- `../02-vm-template` ya aplicado — hace falta el template
  `ubuntu-2404-k8s-base`.
- `VM_SSH_KEYS` (tu clave pública) definida en `.envrc.private` de este
  directorio — la referencian `cluster.yaml.sample`/`cluster.yaml`/
  `cluster-tooling.yaml` vía `envsubst`.
- El repositorio del provider `proxmox` de `clusterctl` configurado (ver
  la sección siguiente).

## Antes de empezar

```bash
kind create cluster --name clusterctl
kubectl get nodes
```

## Preparando el repositorio del provider oficial

Proxmox no es un provider "core" de `clusterctl` (no viene en su lista por
defecto), así que hay que decirle dónde buscarlo:

```bash
mkdir -p ~/.config/cluster-api/
cat > ~/.config/cluster-api/clusterctl.yaml <<EOF
providers:
  - name: "proxmox"
    url: https://github.com/ionos-cloud/cluster-api-provider-proxmox/releases/latest/infrastructure-components.yaml
    type: "InfrastructureProvider"
EOF
```

```bash
clusterctl generate provider -i proxmox --raw | grep image
```

## Credenciales

Antes de `clusterctl init`, este directorio necesita el token `capi-management`
(sale de `tokens.yaml`, generado por `01-proxmox-terraform`)
para que el controller de capmox pueda autenticarse contra Proxmox.

Sin esto, `clusterctl init` crea el controller con credenciales vacías y
todo falla más adelante con `"No credentials found, ProxmoxCluster missing
credentialsRef"` al intentar crear las VMs.

## Init

```bash
clusterctl init --infrastructure proxmox --addon helm --ipam in-cluster
```

- El addon de helm instala charts por label
- `--ipam in-cluster` asigna IPs sin necesitar un servidor DHCP

## Generate

```bash
envsubst < cluster.yaml.sample > cluster.yaml
```

Ya tiene todos los ajustes de este entorno (pool, storage,
`templateSelector`, namespace `management`, sin taint de control-plane).
La clave SSH (`${VM_SSH_KEYS}`) la resuelve `envsubst` al aplicar, desde
`.envrc.private`.

```bash
kubectl apply -f cluster.yaml
```

## Seguimiento

> **Prerequisito de red**: la máquina donde corre `kind` (donde vive el
> controller de CAPI) necesita ruta hacia `10.77.100.0/24` — es la red del
> `controlPlaneEndpoint` (VIP de kube-vip).

### Si corrés `kind` fuera de la instancia EC2 (tu laptop)

La API de Proxmox (`:8006`) siempre fue alcanzable por la IP pública de la
instancia, sin nada especial. Pero el `controlPlaneEndpoint` (`10.77.100.2`,
la VIP de kube-vip) vive en la red nested — **no es ruteable desde afuera**,
así que el controller de CAPI en tu `kind` local necesita un túnel hacia
`10.77.100.0/24` a través de la instancia EC2.

```bash
sshuttle -r root@$PROXMOX_HOST_IP -e 'ssh -i ../00-lab/proxmox-over-ec2-key.pem' -l 0.0.0.0:0 10.77.100.0/24
```

- **`--method tproxy`, no el default (`nat`)**: el método `nat` redirige el
  tráfico reenviado (el de contenedores Docker, como los nodos de `kind`) a
  la IP propia de la interfaz de entrada, no a `127.0.0.1` — si nada escucha
  ahí, da `Connection refused` apenas se intenta conectar.
- **`-l 0.0.0.0:0` es obligatorio con `tproxy`**: sin este flag, `sshuttle`
  (todas sus versiones en Linux, incluida la última) bindea igual el
  listener en loopback (`loopback_proxy_port` queda `True` por default en
  `sshuttle/methods/__init__.py` — nadie lo desactiva para `tproxy` en
  Linux), lo que rompe exactamente el mismo caso que `tproxy` debería
  resolver. `-l 0.0.0.0:0` fuerza el bind en todas las interfaces.

```bash
kubectl get cluster,machines,proxmoxmachines -n management
clusterctl describe cluster proxmox-nerdearla -n management
```

El bootstrap de cada VM real (instalación de kubeadm/kubelet/containerd vía
`preKubeadmCommands`) tarda unos minutos y necesita salida a internet — la
tiene, vía la instancia EC2.

```bash
mkdir -p clusters/management/.kube/
clusterctl get kubeconfig proxmox-nerdearla -n management > clusters/management/.kube/config
kubectl --kubeconfig clusters/management/.kube/config get nodes
```

Los nodos van a verse **Not Ready** hasta instalar un CNI (siguiente paso).

## Instalando el CNI

```bash
envsubst < helm-chart-proxies.yaml.sample > helm-chart-proxies.yaml
kubectl apply -f helm-chart-proxies.yaml
```

> Se aplica en el cluster **kind**, no en el cluster de Proxmox — el addon de
> helm hace el trabajo de instalarlo en cualquier cluster con el label
> `baseHelmCharts: enabled`.

```bash
kubectl get helmchartproxies,helmreleaseproxies
kubectl --kubeconfig clusters/management/.kube/config get nodes
helm --kubeconfig clusters/management/.kube/config list -A
```

## Pivot al cluster de management

El nodo del cluster `proxmox-nerdearla` no tiene workers (es solo control-plane).
`cluster.yaml`/`cluster.yaml.sample` ya le dicen a kubeadm que no le ponga
el taint de control-plane (`initConfiguration.nodeRegistration.taints: []`)
— si lo tuviera, `clusterctl init` no podría alojar sus propios pods ahí
(`FailedScheduling`, "1 node(s) had untolerated taint(s)"). Si estás en un
cluster creado antes de ese cambio, sacalo a mano (esto desincroniza el
estado esperado por CAPI y el `Machine` queda marcado `NotReady` por
"NodeKubeadmLabelsAndTaintsSet" — cosmético, no rompe nada, pero mejor
evitarlo con `taints: []` en un cluster nuevo):

```bash
kubectl --kubeconfig clusters/management/.kube/config \
    taint nodes --all node-role.kubernetes.io/control-plane-
```

**Importante**: el `capmox` que se instala acá corre *dentro* de la red
nested (`10.77.100.0/24`), no en tu laptop — usar `PROXMOX_URL` (la IP
pública de la instancia) rompe por NAT hairpin (una instancia de AWS no
puede conectarse a su propia IP pública/elástica desde adentro). Por eso
este `clusterctl init` usa `PROXMOX_URL_INTERNAL` en vez de `PROXMOX_URL`:

```bash
PROXMOX_URL="$PROXMOX_URL_INTERNAL" clusterctl init --kubeconfig clusters/management/.kube/config \
    --infrastructure proxmox --addon helm --ipam in-cluster

clusterctl move --to-kubeconfig clusters/management/.kube/config -n management
```

`-n management`: sin esto, `clusterctl move` usa el namespace por default
del contexto actual (`default`), no encuentra nada ahí (los recursos están
en `management`) y no mueve nada silenciosamente.

Para confirmar que el pivot realmente funcionó (no solo que los objetos
"existen" en el destino):

```bash
kubectl --kubeconfig clusters/management/.kube/config get cluster proxmox-nerdearla -n management -o jsonpath='{.spec.paused}{"\n"}'
# vacio = no pausado, reconciliando activo (esperado despues del pivot)

clusterctl --kubeconfig clusters/management/.kube/config describe cluster proxmox-nerdearla -n management
# STATUS/REASON deben decir True/Available en Cluster y ControlPlane

kubectl --kubeconfig clusters/management/.kube/config logs -n capmox-system deploy/capmox-controller-manager --tail=20
# sin errores de "unable to initialize proxmox api client" en loop
```

A partir de acá, `kind` es descartable (`kind delete cluster --name clusterctl`).

## Segundo cluster: tooling

Con el cluster management ya migrado (pivot hecho), creamos el namespace y
aplicamos el segundo cluster **desde `clusters/management/`** (ahí vive
`cluster-tooling.yaml` — se aplica contra el cluster management, que tiene
los controladores de CAPI después del pivot):

Antes de aplicar el cluster, crear el Secret con el token `capi-tooling`
(sale de `tokens.yaml`, generado por
`01-proxmox-terraform` — ver su README) que
`credentialsRef` referencia en el `ProxmoxCluster` de tooling. Sin esto,
capmox intentaría crear las VMs de tooling con el token de management, que
sus ACLs no lo permiten (aislamiento por pool, ver módulo 01):

```bash
cat ../01-proxmox-terraform/tokens.yaml   # ver tooling.token_value
```

`token_value` viene como `<token_id>!capi=<secreto>` (todo junto — es como Proxmox
lo muestra al crear un token). Hay que partirlo en el `=`: todo lo de antes es
`token`, lo de después es `secret`. Por ejemplo, si `token_value` es
`capi-tooling@pve!capi=6771f42b-47e1-47a6-a127-6cacf659ac2e`:

```bash
kubectl --kubeconfig clusters/management/.kube/config apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: tooling-proxmox-credentials
  namespace: tooling
  labels:
    platform.ionos.com/secret-type: proxmox-credentials
stringData:
  token: "capi-tooling@pve!capi"
  secret: "6771f42b-47e1-47a6-a127-6cacf659ac2e"
  url: "https://<IP del nodo>:8006"
EOF
```

Con el namespace y el Secret ya creados, aplicamos el cluster y los charts:

```bash
envsubst '$VM_SSH_KEYS' < clusters/management/cluster-tooling.yaml | kubectl --kubeconfig clusters/management/.kube/config apply -f -
envsubst < clusters/management/helm-chart-proxies.yaml | kubectl --kubeconfig clusters/management/.kube/config apply -f -
```

```bash
kubectl --kubeconfig clusters/management/.kube/config get cluster,machines,proxmoxmachines -n tooling

mkdir -p clusters/tooling/.kube/
clusterctl --kubeconfig clusters/management/.kube/config get kubeconfig tooling -n tooling > clusters/tooling/.kube/config
kubectl --kubeconfig clusters/tooling/.kube/config get nodes
```

## Qué deja

- Dos clusters de Kubernetes reales corriendo sobre Proxmox: `management`
  (namespace `management`) y `tooling` (namespace `tooling`), cada uno con
  Cilium como CNI.
- Sus kubeconfigs en `clusters/management/.kube/config` y
  `clusters/tooling/.kube/config` (agregado en el gitignores).
- El cluster `kind` de bootstrap queda descartable una vez hecho el pivot
  (`kind delete cluster --name clusterctl`).

`clusters/management/` tiene además su propio [README](clusters/management/README.md)
con un ejemplo opcional de `Service` tipo `LoadBalancer` vía Cilium — no es
un paso necesario del flujo.
