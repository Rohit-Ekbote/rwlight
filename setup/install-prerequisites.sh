#!/bin/bash
# Install prerequisites for rwlight on a bare Linux host (Lima VM or direct Linux)
# Idempotent — safe to run multiple times. Skips already-installed tools.

set -euo pipefail

# Re-exec as root if not already
if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_ALT="amd64" ;;
    aarch64) ARCH_ALT="arm64" ;;
    arm64)   ARCH_ALT="arm64" ;;
    *)       echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

CHANGED=0

# Install system packages (idempotent via apt)
# Always ensure all system packages are present
echo "[INFO] Checking system packages..."
apt-get update -qq
apt-get install -y -qq curl git jq unzip wget rsync

# kubectl
if ! command -v kubectl &>/dev/null; then
    echo "[INFO] Installing kubectl..."
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH_ALT}/kubectl"
    chmod +x /usr/local/bin/kubectl
    CHANGED=1
fi

# helm
if ! command -v helm &>/dev/null; then
    echo "[INFO] Installing helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    CHANGED=1
fi

# terraform
if ! command -v terraform &>/dev/null; then
    echo "[INFO] Installing terraform..."
    TERRAFORM_VERSION="1.12.2"
    wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH_ALT}.zip" -O /tmp/terraform.zip
    unzip -o /tmp/terraform.zip -d /usr/local/bin
    rm -f /tmp/terraform.zip /usr/local/bin/LICENSE.txt
    CHANGED=1
fi

# vault CLI
if ! command -v vault &>/dev/null; then
    echo "[INFO] Installing vault CLI..."
    VAULT_VERSION="1.15.2"
    wget -q "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH_ALT}.zip" -O /tmp/vault.zip
    unzip -o /tmp/vault.zip -d /usr/local/bin
    rm -f /tmp/vault.zip
    CHANGED=1
fi

# k9s
if ! command -v k9s &>/dev/null; then
    echo "[INFO] Installing k9s..."
    K9S_ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
    curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${K9S_ARCH}.tar.gz" | tar xz -C /usr/local/bin k9s
    CHANGED=1
fi

# flux CLI
if ! command -v flux &>/dev/null; then
    echo "[INFO] Installing flux CLI..."
    curl -fsSL https://fluxcd.io/install.sh | bash -s -- /usr/local/bin
    CHANGED=1
fi

# Docker
if ! command -v docker &>/dev/null; then
    echo "[INFO] Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    if [ -n "${SUDO_USER:-}" ]; then
        usermod -aG docker "$SUDO_USER"
    fi
    CHANGED=1
fi

if [ "$CHANGED" -eq 1 ]; then
    echo "[INFO] Prerequisites installed."
else
    echo "[INFO] All prerequisites already installed."
fi
