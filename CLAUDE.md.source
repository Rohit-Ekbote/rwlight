# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RWDev Tool — a self-hosted RunWhen platform local development environment. It provisions a complete Kubernetes-based stack using a Docker setup container that orchestrates k3s, Flux CD, Terraform, Vault, and Gitea.

## Architecture

The system runs inside a Docker container (Alpine-based) that creates and manages a k3s cluster on the host via Docker socket passthrough.

**Three pillars:**
- **`setup/`** — Bash scripts for lifecycle management (install, update, cleanup). Entry point is `setup.sh` which presents an interactive menu. Core orchestration in `setup-rwdev.sh`. Shared utilities in `helpers.sh`.
- **`tf/`** — Terraform IaC. `tf/local/config/` holds the root module; `tf/modules/gitea/` and `tf/modules/vault/` are reusable modules for provisioning Gitea (self-hosted git) and Vault (secrets management with GitHub auth).
- **`flux/`** — GitOps configuration managed by Flux CD. `flux/apps/` contains 7 application namespaces (backend-services, corestate, gitservice, llm-gateway, runner-system, ui, worksync-system). `flux/infrastructure/` contains base resources plus cert-manager, mimir, minio, postgres, runner-system, and vault. `flux/clusters/` holds cluster-specific kustomizations.

## Key Commands

All commands run **inside the setup container**, not on the host directly.

```sh
# Build and push the container image
docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/runwhen/runwhen-self-hosted:v<tag> --push .

# Run the setup container (interactive menu)
docker run --rm -it \
  --name runwhen-self-hosted-setup-helper \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -p 3000:3000 \
  runwhen-self-hosted

# Inside the container, the menu offers:
# 1) install  — runs setup-rwdev.sh (creates k3s cluster, runs terraform, bootstraps flux)
# 2) update   — runs update-rwdev.sh (syncs flux configs, re-runs terraform)
# 3) cleanup  — runs clean-rwdev.sh (tears down cluster)
# 4) bash     — drops to shell
```

## Configuration

Edit `setup/vars.env` before running setup. Key variables: `SUBDOMAIN`, `DOMAIN`, `CLUSTER`, `GITEA_ADMIN_*`, S3/MinIO credentials, and `MIMIR_BUCKET_NAME`. The `KUBECONFIG` path defaults to `/mnt/k3s-disk/k3s-dev-platform-kubeconfig`.

## System Requirements

The setup script validates: 8+ CPU cores, 12GB+ RAM, 256GB+ disk space.

## Conventions

- All setup scripts are Bash with `set -euo pipefail`. Use the logging functions from `helpers.sh` (`log_info`, `log_success`, `log_warning`, `log_error`) for colored output.
- Flux manifests follow the standard Kustomization pattern with `kustomization.yaml` files referencing HelmRelease or raw YAML resources.
- Terraform modules use standard variable/output patterns. The root module at `tf/local/config/` wires modules together.
- Private container images are pulled from `us-docker.pkg.dev/runwhen-nonprod-shared/private-platform-images/` and pushed to the local k3d registry at `k3d-k3d-registry:60560`.
