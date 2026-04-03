#!/bin/bash

# RunWhen Dev Environment Setup Script
# This script automates the setup process for the rwdev platform development environment
# Note: This script excludes "Runner Setup" as requested

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TF_SUCCESS='false'
EXIT_CODE=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Detect OS

    OS="$(uname -s)"

    # Check CPU (macOS vs Linux)
    if [ "$OS" = "Darwin" ]; then
        cpu_cores=$(sysctl -n hw.ncpu)
    else
        cpu_cores=$(nproc)
    fi
    
    if [ "$cpu_cores" -lt 4 ]; then
        log_warning "CPU cores: $cpu_cores (minimum: 4)"
    else
        log_success "CPU cores: $cpu_cores ✓"
    fi
    
    # Check RAM (macOS vs Linux)
    if [ "$OS" = "Darwin" ]; then
        total_ram_bytes=$(sysctl -n hw.memsize)
        total_ram=$((total_ram_bytes / 1024 / 1024 / 1024))
    else
        total_ram=$(free -g | awk '/^Mem:/{print $2}')
    fi
    
    if [ "$total_ram" -lt 8 ]; then
        log_warning "RAM: ${total_ram}GB (minimum: 8GB, recommended: 10GB)"
    else
        log_success "RAM: ${total_ram}GB ✓"
    fi
    
    # Check available disk space  (macOS vs Linux)
    if [ "$OS" = "Darwin" ]; then
        available_disk=$(df -g / | awk 'NR==2 {print $4}')
    else
        available_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    
    if [ "$available_disk" -lt 50 ]; then
        log_warning "Available disk space: ${available_disk}GB (minimum: 50GB)"
    else
        log_success "Available disk space: ${available_disk}GB ✓"
    fi
}

# Platform setup
setup_platform() {
    log_info "Setting up platform..."
    
    # Ensure k3s data directory exists
    sudo mkdir -p /mnt/k3s-disk

    # Create k3s cluster
    log_info "Creating k3s cluster..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sudo sh -

    sudo tee /etc/rancher/k3s/config.yaml > /dev/null <<EOF
cluster-init: true
data-dir: /mnt/k3s-disk/k3s-data
write-kubeconfig: /mnt/k3s-disk/k3s-dev-platform-kubeconfig
write-kubeconfig-mode: 644
token: 12345
disable:
  - traefik
tls-san:
  - k8s.${SUBDOMAIN}.${DOMAIN}
EOF

    sudo systemctl restart k3s

    export KUBECONFIG=/mnt/k3s-disk/k3s-dev-platform-kubeconfig

    # Wait for kubeconfig to be created and k3s to be ready
    log_info "Waiting for k3s to be ready..."
    for i in $(seq 1 60); do
        if [ -f "$KUBECONFIG" ] && kubectl get nodes &>/dev/null; then
            break
        fi
        sleep 2
    done

    log_success "Platform setup completed"
}

# install gitea
setup_gitea() {
    log_info "Setting up gitea..."
    chmod +x "./scripts/install_gitea.sh"
    if HELM_CONFIG_HOME=/tmp/.helm "./scripts/install_gitea.sh"; then
        log_success "gitea installed"
    else
        log_error "gitea installation failed"
        exit 1
    fi
}

# Perform flux bootstrap
flux_bootstrap() {
    log_info "Performing flux bootstrap..."
    
    chmod +x "./scripts/bootstrap.sh"
    if "./scripts/bootstrap.sh"; then    
        log_success "Flux bootstrap completed"
    else
        log_error "flux bootstrap failed"
        exit 1
    fi
}

# Create platform cluster configmap
create_configmap() {
    log_info "Creating platform-cluster-cluster-vars configmap..."

    chmod +x "./scripts/create_configmap.sh"
    
    if "./scripts/create_configmap.sh"; then
        log_success "Configmap created"
    else
        log_error "failed to create platform configmap"
        exit 1
    fi
}

# Create image pull secret
create_image_pull_secret() {
    log_info "Creating image pull secret..."
    cd "${SETUP_DIR}"
    
    chmod +x "./scripts/create_image_pull_secret.sh"
    
    if (cd "scripts"; ./create_image_pull_secret.sh); then
        log_success "Image pull secret created"
    else
        log_error "failed to create image pull secret"
        exit 1
    fi
}

# Configure gitea and vault
configure_gitea_vault() {
    log_info "Configuring gitea and vault..."

    # Wait for vault-0 pod to be Ready
    log_info "Waiting for vault-0 pod to be created..."
    until kubectl get pod vault-0 -n vault >/dev/null 2>&1; do sleep 2; done
    
    log_info "Waiting for vault-0 pod to be ready..."
    if ! kubectl wait --for=condition=Ready pod/vault-0 --timeout=300s -n vault; then
        log_error "vault-0 pod did not become ready in time"
        exit 1
    fi

    # Initialize vault if not already initialized
    if ! kubectl exec -n vault vault-0 -c vault -- env VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json | jq -e ".initialized" | grep -q true; then
        log_info "Initializing Vault..."
        INIT_OUTPUT=$(kubectl exec -n vault vault-0 -c vault -- env VAULT_ADDR=http://127.0.0.1:8200 vault operator init -key-shares=1 -key-threshold=1 -format=json)

        VAULT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')

        echo "${VAULT_TOKEN}" > .vault-token
        chmod 600 .vault-token

        cp .vault-token "${TF_DIR}/"

        log_success "Vault initialized and root token stored in .vault-token"
    else
        log_info "Vault already initialized"

        if [ -f .vault-token ]; then
            VAULT_TOKEN=$(cat .vault-token)
            log_info "Loaded Vault root token from .vault_token"
        else
            read -s -p "Enter vault root token: " VAULT_TOKEN
            echo
        fi
    fi

    export VAULT_TOKEN

    FULL_HOST="${SUBDOMAIN}.${DOMAIN}"

    cd "$TF_DIR/local/config/" && cat > terraform.tfvars <<EOF
public_https_endpoints = {
    gitea = {
        host = "gitea.${FULL_HOST}"
        path = "/"
    }
    papi = {
        host = "papi.${FULL_HOST}"
        path = "/livez"
    }
    vault = {
        host = "vault.${FULL_HOST}"
        path = "v1/sys/health"
    }
}

gitea_platform_group  = "runwhen-platform"
platform_cluster_name = "${CLUSTER}"
basename              = "local"
gitea_admin_password  = "${GITEA_ADMIN_PASS}"
EOF

    ### Port forwards for Terraform (Gitea + Vault) ###
    log_info "Setting up port forwards to Gitea and Vault..."
    fuser -k 3000/tcp 2>/dev/null || true
    fuser -k 8200/tcp 2>/dev/null || true
    kubectl port-forward -n gitea svc/gitea-http 3000:3000 > /tmp/portforward-gitea.log 2>&1 &
    GITEA_PF_PID=$!
    kubectl port-forward -n vault svc/vault 8200:8200 > /tmp/portforward-vault.log 2>&1 &
    VAULT_PF_PID=$!

    cleanup_port_forwards() {
        kill $GITEA_PF_PID 2>/dev/null || true
        kill $VAULT_PF_PID 2>/dev/null || true
    }
    trap cleanup_port_forwards EXIT

    # Wait for port-forward to be ready
    log_info "Waiting for Gitea port-forward to become ready..."
    for i in $(seq 1 30); do
        if curl -s http://localhost:3000/api/healthz > /dev/null; then
            log_success "Gitea is accessible at localhost:3000"
            break
        fi
        sleep 1
    done

    if ! curl -s http://localhost:3000/api/healthz > /dev/null; then
        log_error "Gitea is not accessible via port forward (timeout after 30s)"
        exit 1
    fi

    log_info "Applying terraform"
    if cd "$TF_DIR/local/config/" && terraform init && terraform plan -out=tfplan && terraform apply -auto-approve tfplan; then
        log_success "Gitea and vault configured"
    else
        log_error "Failed to apply terraform"
        EXIT_CODE=1234
        exit $EXIT_CODE
    fi

    log_info "Committing tf state to gitea"

    # Push updated TF state to Gitea — use a temp clone to avoid git-in-worktree issues
    GITEA_TOKEN=$(kubectl get secret gitea-bootstrap-token --namespace=gitea -o jsonpath='{.data.token}' | base64 -d || true)
    if [ -n "$GITEA_TOKEN" ]; then
        TF_PUSH_TMP=$(mktemp -d)
        GIT_TF_URL="http://${GITEA_ADMIN_USER}:${GITEA_TOKEN}@localhost:3000/platform-setup/infra.git"
        if (cd "$TF_PUSH_TMP" && \
            git clone "$GIT_TF_URL" repo && \
            rsync -a --exclude='.git' "$TF_DIR/" repo/ && \
            cd repo && \
            git config user.name "runwhen-machine" && \
            git config user.email "runwhen-machine@runwhen.com" && \
            git add . && \
            (git commit -m "TF State Commit" || :) && \
            git push origin main -f); then
            log_success "successfully committed tf states to gitea..."
        else
            log_error "Failed to commit tf state to gitea"
            EXIT_CODE=1234
        fi
        rm -rf "$TF_PUSH_TMP"
    else
        log_warning "No Gitea token found, skipping TF state push"
    fi
    TF_SUCCESS='true'
}

# Print final instructions
print_final_instructions() {
    log_success "Setup completed successfully!"
    log_info ""
    log_info "Pasted vault token in '.vault-token' file and k8s context in '${CLUSTER}-kubeconfig' file."
    log_info "To merge the context with your existing contexts, in new terminal run:"
    log_warning "KUBECONFIG=~/.kube/config:${CLUSTER}-kubeconfig kubectl config view --merge --flatten > ~/.kube/config-merged && mv ~/.kube/config-merged ~/.kube/config"
    log_info ""
    log_info "Next steps:"
    log_info "1. Populate GITSERVICE_PLATFORM_PERSONAL_ACCESS_TOKEN & OPENAI_TOKEN in vault's shared/secrets.py"
    log_info "2. delete existing papi pod"
    log_info "3. Complete UI setup if not done already"
    log_info "4. Create workspace on aws deployment at https://app.${SUBDOMAIN}.${DOMAIN}"
    log_info ""
    log_info "Important URLs:"
    log_info "- App: https://app.${SUBDOMAIN}.${DOMAIN}"
    log_info "- Vault: https://vault.${SUBDOMAIN}.${DOMAIN}"
    log_info "- Gitea: https://gitea.${SUBDOMAIN}.${DOMAIN}"
    log_info "- MinIO Console: https://minio-console.${SUBDOMAIN}.${DOMAIN}"
    log_info ""
}

# Cleanup function
cleanup() {
    log_info "Cleaning up on exit..."
    if [ -n "$TF_DIR" ] && [ -d "$TF_DIR/local/config/" ]; then
        if [[ "$TF_SUCCESS" == "false" ]]; then
            log_info "Terraform state preserved for retry (run install again)"
        fi
    fi
    # Add any cleanup operations here if needed
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Main execution flow
main() {
    export SETUP_DIR="$1"
    export INFRA_DIR="$2"
    export TF_DIR="$3"
    cd "$SETUP_DIR"

    set -a
    source vars.env
    set +a

    log_info "Starting RunWhen Dev Environment Setup..."
    log_info "========================================="
    
    check_requirements
    
    # setup_source
    
    setup_platform
    setup_gitea
    flux_bootstrap
    create_configmap
    configure_gitea_vault
    create_image_pull_secret
    print_final_instructions
    
    log_success "Setup script completed!"
}

# Run main function
main "$@"