#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Must specify a kubernetes version to check: MAJOR.MINOR, for example:"
  echo "   $0 1.32"
  echo exit 1
fi

docker run --rm -it ubuntu:24.04 bash -c "apt-get update && \
  apt install -y apt-transport-https ca-certificates curl gpg && \
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v$1/deb/Release.key \
      | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
   echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$1/deb/ /' \
      | tee /etc/apt/sources.list.d/kubernetes.list && apt-get update && \
      apt list -a kubeadm"

