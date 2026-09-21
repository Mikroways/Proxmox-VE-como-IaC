#!/bin/bash

set -e

if [ -z "$PROXMOX_URL" ]; then
  echo "PROXMOX_URL must be set"
  exit 1
fi
if [ -z "$PROXMOX_USERNAME" ]; then
  echo "PROXMOX_USERNAME must be set"
  exit 1

fi
if [ -z "$PROXMOX_TOKEN" ]; then
  echo "PROXMOX_TOKEN must be set"
  exit 1
fi

if [ -z "$IMAGE_BUILDER_ENV_FILE" ]; then
  echo "IMAGE_BUILDER_ENV_FILE must be set"
  exit 1
fi
if [ ! -s "$IMAGE_BUILDER_ENV_FILE" ]; then
  echo "File $IMAGE_BUILDER_ENV_FILE must exists and have content"
  exit 1
fi

TASK=${1:-help}

# --- Asegurar la ISO en Proxmox antes de llamar a Packer ---
# El downloader de Packer (go-getter) no sigue el 308 Permanent Redirect
# que devuelven releases.ubuntu.com y varios mirrors para pedidos con
# Range header (confirmado en vivo contra este lab - un curl comun si
# sigue el redirect, go-getter no). En vez de que Packer la baje el mismo
# (iso_url), le pedimos a Proxmox que la baje del lado del servidor (API
# download-url, mismo token que ya usamos para todo lo demas) y se la
# pasamos ya presente (iso_file) - iso_url/iso_file son mutuamente
# excluyentes, por eso environment-imagebuilder deja iso_url vacio.
if [ -n "$ISO_FILENAME" ] && [ -n "$ISO_URL" ]; then
  auth=(-H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}")

  existing=$(curl -sk "${auth[@]}" \
    "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/storage/${PROXMOX_ISO_POOL}/content" \
    | grep -o "\"volid\":\"[^\"]*${ISO_FILENAME}\"" || true)

  if [ -z "$existing" ]; then
    echo "ISO no esta en Proxmox todavia - pidiendole que la baje ella misma ($ISO_URL)..."
    checksum_args=()
    if [ -n "$ISO_CHECKSUM" ]; then
      checksum_args=(--data-urlencode "checksum=${ISO_CHECKSUM}" --data-urlencode "checksum-algorithm=sha256")
    fi
    upid=$(curl -sk "${auth[@]}" \
      "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/storage/${PROXMOX_ISO_POOL}/download-url" \
      --data-urlencode "content=iso" \
      --data-urlencode "filename=${ISO_FILENAME}" \
      --data-urlencode "url=${ISO_URL}" \
      "${checksum_args[@]}" \
      | grep -o '"data":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$upid" ]; then
      echo "No se pudo iniciar la descarga en Proxmox (revisa permisos del token imagebuilder)"
      exit 1
    fi

    echo "Proxmox esta bajando la ISO (task $upid)..."
    while true; do
      status=$(curl -sk "${auth[@]}" "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/tasks/${upid}/status")
      running=$(echo "$status" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
      if [ "$running" != "running" ]; then
        exitstatus=$(echo "$status" | grep -o '"exitstatus":"[^"]*"' | cut -d'"' -f4)
        if [ "$exitstatus" != "OK" ]; then
          echo "Fallo la descarga en Proxmox: $exitstatus"
          exit 1
        fi
        break
      fi
      sleep 5
    done
    echo "ISO lista en Proxmox."
  fi

  export ISO_FILE="${PROXMOX_ISO_POOL}:iso/${ISO_FILENAME}"
fi

# envsubst expande "${K8S_VERSION}" (definida en .envrc) dentro del archivo
# antes de que Docker lo lea - --env-file por si solo no interpola nada.
# Restringido a esa unica variable (envsubst '$K8S_VERSION') para no tocar
# ningun otro "$" que pueda aparecer en el archivo.
docker run -it --rm --net=host \
    --env-file <(envsubst '$K8S_VERSION' < "$IMAGE_BUILDER_ENV_FILE") \
    -e PROXMOX_URL \
    -e PROXMOX_USERNAME \
    -e PROXMOX_TOKEN \
    -e ISO_FILE \
    -v /tmp:/home/imagebuilder/downloaded_iso_path \
      registry.k8s.io/scl-image-builder/cluster-node-image-builder-amd64:v0.1.46 $TASK
