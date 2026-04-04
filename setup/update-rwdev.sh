#!/bin/bash

set -e  # Exit on any error

set -a
source vars.env
source ./helpers.sh
set +a

NEW_BRANCH=${VERSION}
BACKUP_BRANCH="pre-${VERSION}-bkp"

cleanup() {
    log_info "Cleaning up on exit..."
    rm -rf "$HOME/runwhen-platform-self-hosted-local-dev"
    rm -rf "$HOME/infra"
    clean_docker_permissions
    log_success "update cleanup done"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

setup_platform() {
    log_info "Connecting container to network ${NETWORK}..."
    if ! docker network connect "$NETWORK" "$(hostname)" >/dev/null 2>&1; then
        log_error "Failed to connect container to network ${NETWORK}"
        exit 1
    else
        log_success "Connected container to network ${NETWORK}"
    fi

    log_info "getting ${CLUSTER} cluster details..."
    if ! k3d cluster list | grep -q "$CLUSTER"; then
        log_error "cluster: ${CLUSTER} does not exist"
        exit 1
    fi

    mkdir ~/.kube
    touch ~/.kube/config
    k3d kubeconfig get ${CLUSTER} | \
        sed 's#https://0\.0\.0\.0:[0-9]*#https://k3d-'${CLUSTER}'-serverlb:6443#' | \
        sed 's#https://127\.0\.0\.1:[0-9]*#https://k3d-'${CLUSTER}'-serverlb:6443#' \
        > ~/.kube/config
    
    echo "$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k3d-${CLUSTER}-serverlb) gitea.local.runwhen.com" | sudo tee -a /etc/hosts > /dev/null
}

setup_container_routing() {
    log_info "Extracting LoadBalancer hostname/IP..."
    if GATEWAY_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k3d-${CLUSTER}-serverlb 2>/dev/null); then
        : # normal
    elif GATEWAY_IP=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' k3d-${CLUSTER}-serverlb 2>/dev/null); then
        : # sudo
    else
        log_error "Failed to get k3d serverlb IP"
        exit 1
    fi
    
    if [ "$OS" = "Darwin" ]; then
        GATEWAY_IP="192.168.65.254"
    fi
    
    log_info "Gateway IP: $GATEWAY_IP"
    
    # Add routing to container's /etc/hosts as root
    echo "$GATEWAY_IP vault.${SUBDOMAIN}.${DOMAIN}" | sudo tee -a /etc/hosts > /dev/null
    echo "$GATEWAY_IP gitea.${SUBDOMAIN}.${DOMAIN}" | sudo tee -a /etc/hosts > /dev/null
    
    log_success "Container domain routing configured"
}

get_repo_details() {
    export GITEA_TOKEN=$(
        kubectl get secret gitea-bootstrap-token -n gitea -o jsonpath='{.data.token}' | base64 -d
    )
}

clone_repo() {
    rm -rf "$HOME/runwhen-platform-self-hosted-local-dev"
    rm -rf "$HOME/infra"
    log_info "getting current infra source code..."
    GIT_SSL_NO_VERIFY=true git clone https://gitea.local.runwhen.com/platform-setup/runwhen-platform-self-hosted-local-dev.git "$HOME/runwhen-platform-self-hosted-local-dev"
    GIT_SSL_NO_VERIFY=true git clone https://gitea.local.runwhen.com/platform-setup/infra.git "$HOME/infra"
}

fix_git_config() {
    log_info "configuring git"
    (
        cd "$HOME/runwhen-platform-self-hosted-local-dev" &&
        git config --local user.name root &&
        git config --local user.email "admin@${SUBDOMAIN}.${DOMAIN}" &&
        git config merge.tool vimdiff &&
        git config mergetool.prompt false &&
        git remote set-url origin "https://root:${GITEA_TOKEN}@gitea.local.runwhen.com/platform-setup/runwhen-platform-self-hosted-local-dev.git"
    )
    (
        cd "$HOME/infra" &&
        git config --local user.name root &&
        git config --local user.email "admin@${SUBDOMAIN}.${DOMAIN}" &&
        git config merge.tool vimdiff &&
        git config mergetool.prompt false &&
        git remote set-url origin "https://root:${GITEA_TOKEN}@gitea.local.runwhen.com/platform-setup/infra.git"
    )
    log_info "git configuration successful"
}

backup_current_state() {
    log_info "backing up current state"
    (
        cd "$HOME/runwhen-platform-self-hosted-local-dev" &&
        git switch main && GIT_SSL_NO_VERIFY=true git pull origin main &&
        git checkout -b ${BACKUP_BRANCH} &&
        GIT_SSL_NO_VERIFY=true git push origin ${BACKUP_BRANCH}
    )
    (
        cd "$HOME/infra" &&
        git switch main && GIT_SSL_NO_VERIFY=true git pull origin main &&
        git checkout -b ${BACKUP_BRANCH} &&
        GIT_SSL_NO_VERIFY=true git push origin ${BACKUP_BRANCH}
    )
    log_success "successfully backed up current state to ${BACKUP_BRANCH}"
}
ingest_updated_code() {
    setup_dir="$1"
    infra_dir="$2"
    log_info "setting up updated code"
    (
        cd "$HOME/runwhen-platform-self-hosted-local-dev" &&
        git switch main &&
        git checkout -b ${NEW_BRANCH} &&
        rsync -av "${setup_dir}/" "$HOME/runwhen-platform-self-hosted-local-dev/"
    )
    (
        cd "$HOME/infra" &&
        git switch main &&
        git checkout -b ${NEW_BRANCH} &&
        rsync -av "${infra_dir}/" "$HOME/infra/"
    )
    log_info "updates are in place and ready to merge"
}

merge_new_code() {
    log_info "merging updates to main"
    for repo in "$HOME/runwhen-platform-self-hosted-local-dev" "$HOME/infra"; do
        (
            cd "$repo" || exit
            git switch main
            git merge ${NEW_BRANCH} --no-commit --no-ff || true
            git mergetool || true
            git add .
            git commit -m "Merged ${NEW_BRANCH} into main" || true
        )
    done
    log_success "successfully updated code on main"
}

apply_terraform() {
    log_info "reading vault token..."
    if [ -f "$HOME/infra/.vault-token" ]; then
        VAULT_TOKEN=$(<"$HOME/infra/.vault-token")
        VAULT_TOKEN="${VAULT_TOKEN//$'\n'/}"
        log_info "Loaded Vault root token from .vault-token"
    else
        read -s -p "Enter vault root token: " VAULT_TOKEN
        echo
    fi

    unset GITEA_TOKEN
    export VAULT_TOKEN
    
    log_info "applying terraform"
    (
        cd "$HOME/infra/local/config" &&
        terraform plan -out="tfplan-${VERSION}" &&
        terraform apply -auto-approve "tfplan-${VERSION}"
    )
    log_success "successfully applied terraform"

    log_info "commiting new terraform state"
    (
        cd "$HOME/infra" &&
        git add . &&
        git commit -m "TF State Commit" || .
    )
    log_success "new tfstate committed"
}

push_updated_code() {
    log_info "pushing updated code"
    (
        cd "$HOME/runwhen-platform-self-hosted-local-dev" &&
        git switch main && GIT_SSL_NO_VERIFY=true git push origin main
    )
    (
        cd "$HOME/infra" &&
        git switch main && GIT_SSL_NO_VERIFY=true git push origin main
    )
}

main() {
    flux_dir="$1"
    infra_dir="$2"

    log_info "Starting RunWhen Dev Environment Setup Update..."
    log_info "========================================="

    fix_docker_permissions
    setup_platform
    setup_container_routing
    get_repo_details
    clone_repo
    fix_git_config
    backup_current_state
    ingest_updated_code "${flux_dir}" "${infra_dir}"
    merge_new_code
    apply_terraform
    push_updated_code

    log_success "Update successfull"
}

# Run main function
main "$@"
