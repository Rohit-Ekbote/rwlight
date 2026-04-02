#!/bin/bash
# Install prerequisites for rwlight on a bare Linux host (Lima VM or direct Linux)
# Run with: sudo ./setup/install-prerequisites.sh

set -euo pipefail

echo "[INFO] Installing rwlight prerequisites..."

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_ALT="amd64" ;;
    aarch64) ARCH_ALT="arm64" ;;
    arm64)   ARCH_ALT="arm64" ;;
    *)       echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "[INFO] Architecture: $ARCH ($ARCH_ALT)"

# Install system packages
echo "[INFO] Installing system packages..."
apt-get update -qq
apt-get install -y -qq curl git jq unzip wget rsync

# kubectl
if ! command -v kubectl &>/dev/null; then
    echo "[INFO] Installing kubectl..."
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH_ALT}/kubectl"
    chmod +x /usr/local/bin/kubectl
else
    echo "[INFO] kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

# helm
if ! command -v helm &>/dev/null; then
    echo "[INFO] Installing helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "[INFO] helm already installed: $(helm version --short)"
fi

# terraform
if ! command -v terraform &>/dev/null; then
    echo "[INFO] Installing terraform..."
    TERRAFORM_VERSION="1.12.2"
    wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH_ALT}.zip" -O /tmp/terraform.zip
    unzip -o /tmp/terraform.zip -d /usr/local/bin
    rm /tmp/terraform.zip
else
    echo "[INFO] terraform already installed: $(terraform version -json | jq -r .terraform_version)"
fi

# vault CLI
if ! command -v vault &>/dev/null; then
    echo "[INFO] Installing vault CLI..."
    VAULT_VERSION="1.15.2"
    wget -q "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH_ALT}.zip" -O /tmp/vault.zip
    unzip -o /tmp/vault.zip -d /usr/local/bin
    rm /tmp/vault.zip
else
    echo "[INFO] vault already installed: $(vault version)"
fi

# flux CLI
if ! command -v flux &>/dev/null; then
    echo "[INFO] Installing flux CLI..."
    curl -fsSL https://fluxcd.io/install.sh | bash -s -- /usr/local/bin
else
    echo "[INFO] flux already installed: $(flux --version)"
fi

# Docker
if ! command -v docker &>/dev/null; then
    echo "[INFO] Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    # Add current user to docker group if not root
    if [ "$(id -u)" -ne 0 ] && [ -n "${SUDO_USER:-}" ]; then
        usermod -aG docker "$SUDO_USER"
        echo "[INFO] Added $SUDO_USER to docker group (re-login required)"
    fi
else
    echo "[INFO] Docker already installed: $(docker --version)"
fi

echo ""
echo "[SUCCESS] All prerequisites installed:"
echo "  kubectl:   $(kubectl version --client --short 2>/dev/null || echo 'installed')"
echo "  helm:      $(helm version --short 2>/dev/null)"
echo "  terraform: $(terraform version -json 2>/dev/null | jq -r .terraform_version)"
echo "  vault:     $(vault version 2>/dev/null)"
echo "  flux:      $(flux --version 2>/dev/null)"
echo "  docker:    $(docker --version 2>/dev/null)"
echo ""
echo "You can now run: ./setup/setup.sh"
