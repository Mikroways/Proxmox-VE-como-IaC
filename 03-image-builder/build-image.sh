#!/bin/bash

set -e

if [ -z "$PROXMOX_VE_ENDPOINT" ]; then
  echo "PROXMOX_VE_ENDPOINT must be set"
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
if  [ ! -s "$IMAGE_BUILDER_ENV_FILE" ]; then
  echo "File $IMAGE_BUILDER_ENV_FILE must exists and have content"
  exit 1
fi

TASK=${1:-help}

docker run -it --rm --net=host --env-file $IMAGE_BUILDER_ENV_FILE \
    -e PROXMOX_URL=$PROXMOX_VE_ENDPOINT  \
    -e PROXMOX_USERNAME=$PROXMOX_USERNAME  \
    -e PROXMOX_TOKEN=$PROXMOX_TOKEN  \
    -v /tmp:/home/imagebuilder/downloaded_iso_path \
      registry.k8s.io/scl-image-builder/cluster-node-image-builder-amd64:v0.1.46 $TASK
