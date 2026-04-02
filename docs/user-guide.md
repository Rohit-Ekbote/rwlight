# rwlight User Guide

rwlight is a lightweight RunWhen platform setup for small VMs (4 CPU / 8 GB RAM). It supports three deployment targets:

- **macOS (MacBook)** — runs inside a Lima VM
- **Local Linux** — runs directly on the host
- **Remote Linux VM** — runs on a cloud or on-prem VM you SSH into

---

## Prerequisites (All Platforms)

### GCP Artifact Registry Key

RunWhen platform images are stored in GCP Artifact Registry (`us-docker.pkg.dev/runwhen-nonprod-shared/private-platform-images/`). You need a GCP service account key with `Artifact Registry Reader` access.

**Option A: Extract from an existing RunWhen cluster**

If you have `kubectl` access to a running RunWhen cluster (e.g., rdebug), extract the key:

```bash
kubectl get secret gcp-registry-key -n backend-services \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | \
  jq -r '.auths["us-docker.pkg.dev"].password' > gcp-key.json
```

**Option B: Create a new service account key**

```bash
# Requires gcloud CLI and IAM permissions on runwhen-nonprod-shared
gcloud iam service-accounts keys create gcp-key.json \
  --iam-account=<SERVICE_ACCOUNT_EMAIL> \
  --project=runwhen-nonprod-shared
```

**Option C: Request from your team**

Ask a team member with access to provide the `gcp-key.json` file.

Once you have the key, copy it into the repo:

```bash
cp gcp-key.json setup/scripts/gcp-key.json
```

> **Security:** Never commit this file to git. It is already in `.gitignore`.

---

## Deployment Target 1: macOS (MacBook)

### Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- 16 GB RAM recommended (10 GB allocated to VM)
- 100 GB free disk space
- Homebrew installed

### Step 1: Install Lima

```bash
brew install lima
```

Verify:
```bash
limactl --version
```

### Step 2: Clone the repo

```bash
git clone https://github.com/Rohit-Ekbote/rwlight.git
cd rwlight
git checkout emdash/brainstorm-41w
```

### Step 3: Add GCP key

```bash
cp /path/to/your/gcp-key.json setup/scripts/gcp-key.json
```

### Step 4: Configure environment

Edit `setup/vars.env` and set `SUBDOMAIN` to a unique name for your instance:

```bash
SUBDOMAIN=myname-01
```

Leave `DOMAIN=local.runwhen.com` as-is unless you have a custom domain.

### Step 5: Create the Lima VM

```bash
./rwlight-vm create
```

Default resources: 4 CPUs, 10 GiB RAM, 80 GiB disk.

To customize:
```bash
./rwlight-vm create --cpus 6 --memory 12 --disk 100
```

This creates an AMD64 Ubuntu VM using Rosetta emulation (for compatibility with RunWhen container images). Takes ~5-10 minutes on first run.

### Step 6: SSH into the VM

```bash
./rwlight-vm ssh
```

### Step 7: Run the platform setup

Inside the VM:

```bash
cd /Users/<your-username>/path/to/rwlight
./setup/setup.sh
```

The setup menu appears. Choose **install**.

The script will:
1. Check system requirements
2. Install k3s (Kubernetes)
3. Install Gitea (Git hosting)
4. Bootstrap Flux CD (GitOps)
5. Create platform ConfigMaps
6. Initialize and configure Vault (secrets management)
7. Run Terraform (provisions Gitea repos + Vault policies)
8. Create image pull secrets for GCP registry

**Takes ~15-30 minutes.** Terraform may prompt you to confirm — type `yes` when asked.

### Step 8: Verify the platform

Still inside the VM:

```bash
export KUBECONFIG=/mnt/k3s-disk/k3s-dev-platform-kubeconfig

# Check all pods are running
kubectl get pods -A

# Check resource usage
kubectl top nodes
```

All pods should reach `Running` or `Completed` status within 5-10 minutes after setup completes. Some pods may restart once or twice during initial startup — this is normal.

### Step 9: Access the platform from your Mac

On your **Mac** (not the VM), add DNS entries to `/etc/hosts`:

```bash
sudo tee -a /etc/hosts << EOF
127.0.0.1  app.myname-01.local.runwhen.com
127.0.0.1  papi.myname-01.local.runwhen.com
127.0.0.1  gitea.myname-01.local.runwhen.com
127.0.0.1  vault.myname-01.local.runwhen.com
127.0.0.1  minio.myname-01.local.runwhen.com
127.0.0.1  minio-console.myname-01.local.runwhen.com
127.0.0.1  agentfarm.myname-01.local.runwhen.com
127.0.0.1  runner.myname-01.local.runwhen.com
127.0.0.1  slack.myname-01.local.runwhen.com
127.0.0.1  webhooks.myname-01.local.runwhen.com
127.0.0.1  runner-mimir-tenant.myname-01.local.runwhen.com
127.0.0.1  app-dev.myname-01.local.runwhen.com
EOF
```

Replace `myname-01` with the `SUBDOMAIN` you set in Step 4.

Open in your browser:

| Service | URL |
|---------|-----|
| RunWhen App | `https://app.myname-01.local.runwhen.com` |
| Gitea | `https://gitea.myname-01.local.runwhen.com` |
| Vault | `https://vault.myname-01.local.runwhen.com` |
| MinIO Console | `https://minio-console.myname-01.local.runwhen.com` |
| PAPI | `https://papi.myname-01.local.runwhen.com` |

> **Note:** You'll see a certificate warning — these use Let's Encrypt staging certificates. Accept the self-signed certificate to proceed.

### macOS VM Management

```bash
./rwlight-vm status    # Check VM status and IP
./rwlight-vm stop      # Stop VM (preserves all state)
./rwlight-vm start     # Start a stopped VM
./rwlight-vm ssh       # SSH into running VM
./rwlight-vm delete    # Delete VM entirely (destroys all data)
```

---

## Deployment Target 2: Local Linux

### Requirements

- Ubuntu 22.04+ or Debian 12+ (other distros may work but are untested)
- 4+ CPU cores
- 8+ GB RAM (10+ GB recommended)
- 80+ GB free disk space
- Docker installed
- `sudo` access
- Disk mounted at `/mnt/k3s-disk` (or modify `KUBECONFIG` path in `vars.env`)

### Step 1: Prepare the disk

k3s stores its data at `/mnt/k3s-disk`. Create this directory:

```bash
sudo mkdir -p /mnt/k3s-disk
```

If you have a separate data disk, mount it there. See `mount_disk.md` for details.

### Step 2: Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect
```

### Step 3: Install required tools

```bash
sudo apt-get update
sudo apt-get install -y curl git jq
```

### Step 4: Clone the repo

```bash
git clone https://github.com/Rohit-Ekbote/rwlight.git
cd rwlight
git checkout emdash/brainstorm-41w
```

### Step 5: Add GCP key

```bash
cp /path/to/your/gcp-key.json setup/scripts/gcp-key.json
```

### Step 6: Configure environment

Edit `setup/vars.env`:

```bash
SUBDOMAIN=myname-01
```

### Step 7: Run the platform setup

```bash
./setup/setup.sh
```

Choose **install** from the menu. Follow the same process as described in the macOS section, Step 7.

### Step 8: Verify and access

```bash
export KUBECONFIG=/mnt/k3s-disk/k3s-dev-platform-kubeconfig
kubectl get pods -A
```

Access services using the machine's IP address. Add entries to your local `/etc/hosts` (on the machine you're browsing from) pointing the service hostnames to the Linux machine's IP.

---

## Deployment Target 3: Remote Linux VM

### Requirements

- A Linux VM (Ubuntu 22.04+, Debian 12+, or similar)
- 4+ CPU cores, 8+ GB RAM, 80+ GB disk
- SSH access from your workstation
- Docker installed on the VM
- Ports 80 and 443 reachable from your workstation (for browser access)
- Port 22 open for SSH

### Step 1: SSH into the remote VM

```bash
ssh user@<VM_IP>
```

### Step 2: Prepare the VM

Install Docker and tools:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo apt-get update && sudo apt-get install -y curl git jq
# Log out and back in
```

Create the k3s data directory:

```bash
sudo mkdir -p /mnt/k3s-disk
```

If the VM has a separate data disk, mount it at `/mnt/k3s-disk`. See `mount_disk.md`.

### Step 3: Clone the repo on the VM

```bash
git clone https://github.com/Rohit-Ekbote/rwlight.git
cd rwlight
git checkout emdash/brainstorm-41w
```

### Step 4: Transfer the GCP key to the VM

From your workstation:

```bash
scp /path/to/your/gcp-key.json user@<VM_IP>:~/rwlight/setup/scripts/gcp-key.json
```

### Step 5: Configure environment

On the VM, edit `setup/vars.env`:

```bash
SUBDOMAIN=myname-01
```

### Step 6: Run the platform setup

On the VM:

```bash
cd ~/rwlight
./setup/setup.sh
```

Choose **install**. Follow the same process as macOS Step 7.

### Step 7: Verify

On the VM:

```bash
export KUBECONFIG=/mnt/k3s-disk/k3s-dev-platform-kubeconfig
kubectl get pods -A
kubectl top nodes
```

### Step 8: Access from your workstation

On your **workstation**, add DNS entries pointing to the VM's IP:

```bash
sudo tee -a /etc/hosts << EOF
<VM_IP>  app.myname-01.local.runwhen.com
<VM_IP>  papi.myname-01.local.runwhen.com
<VM_IP>  gitea.myname-01.local.runwhen.com
<VM_IP>  vault.myname-01.local.runwhen.com
<VM_IP>  minio.myname-01.local.runwhen.com
<VM_IP>  minio-console.myname-01.local.runwhen.com
<VM_IP>  agentfarm.myname-01.local.runwhen.com
<VM_IP>  runner.myname-01.local.runwhen.com
<VM_IP>  slack.myname-01.local.runwhen.com
<VM_IP>  webhooks.myname-01.local.runwhen.com
<VM_IP>  runner-mimir-tenant.myname-01.local.runwhen.com
<VM_IP>  app-dev.myname-01.local.runwhen.com
EOF
```

Replace `<VM_IP>` with the actual IP of the remote VM.

### Firewall Notes

Ensure ports 80 (HTTP) and 443 (HTTPS) are open on the VM's firewall. For GCP VMs:

```bash
gcloud compute firewall-rules create allow-rwlight-ingress \
  --allow tcp:80,tcp:443 \
  --target-tags=<VM_TAG> \
  --project=<PROJECT>
```

For AWS:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG_ID> \
  --protocol tcp --port 80 --cidr <YOUR_IP>/32

aws ec2 authorize-security-group-ingress \
  --group-id <SG_ID> \
  --protocol tcp --port 443 --cidr <YOUR_IP>/32
```

---

## Post-Setup Configuration

After the platform is running on any target, complete these steps:

### 1. Populate Vault Secrets

The setup script prints the Vault root token. Use it to add required secrets:

```bash
export VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"
export VAULT_TOKEN="<root-token-from-setup>"

# Add platform access token (required for GitService)
vault kv put shared/data/platform-secrets \
  GITSERVICE_PLATFORM_PERSONAL_ACCESS_TOKEN="<gitea-admin-token>"

# Add OpenAI key (required for LLM Gateway)
vault kv put shared/data/litellm-secrets \
  OPENAI_TOKEN="<your-openai-api-key>"
```

### 2. Restart PAPI

After Vault secrets are populated, restart PAPI to pick them up:

```bash
kubectl rollout restart deployment papi -n backend-services
```

### 3. Verify Services

Check all services are healthy:

```bash
# All pods running
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Mimir monolithic is serving queries
kubectl exec -n backend-services deploy/papi -- \
  curl -s "http://mimir-monolithic.mimir.svc.cluster.local:8080/prometheus/api/v1/query?query=up" | head -c 200

# Redis sentinel is healthy
kubectl exec -n backend-services redis-sentinel-node-0 -- redis-cli ping
```

---

## Day-to-Day Operations

### Updating the Platform

After pulling new code or changing configurations:

```bash
./setup/setup.sh
# Choose "update" from the menu
```

### Tearing Down

To completely remove the platform:

```bash
./setup/setup.sh
# Choose "cleanup" from the menu
```

This removes k3s, all data, and the kubeconfig. On macOS, also run `./rwlight-vm delete` to remove the VM.

### Checking Resource Usage

```bash
export KUBECONFIG=/mnt/k3s-disk/k3s-dev-platform-kubeconfig

# Node-level usage
kubectl top nodes

# Pod-level usage (sorted by memory)
kubectl top pods -A --sort-by=memory

# Check for pods not running
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

### Viewing Logs

```bash
# Platform API
kubectl logs -n backend-services deploy/papi -f

# Mimir metrics
kubectl logs -n mimir deploy/mimir-monolithic -f

# Flux reconciliation
kubectl logs -n flux-system deploy/kustomize-controller -f

# Any service
kubectl logs -n <namespace> deploy/<service> -f
```

### Accessing kubectl from macOS

If running on a Lima VM, you can copy the kubeconfig to your Mac:

```bash
# Inside the VM
cat /mnt/k3s-disk/k3s-dev-platform-kubeconfig

# On your Mac, save it and set KUBECONFIG
export KUBECONFIG=~/.kube/rwlight-config
```

Note: The kubeconfig references `127.0.0.1:6443` which works because Lima forwards port 6443 from the VM to your Mac.

---

## Troubleshooting

### Pods stuck in Pending

Usually means resource pressure. Check:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl top nodes
```

If memory is exhausted, consider using a larger VM (`./rwlight-vm create --memory 12`).

### Pods in CrashLoopBackOff

Check logs:

```bash
kubectl logs <pod-name> -n <namespace> --previous
```

Common causes:
- Vault secrets not populated (PAPI, Slackbot)
- Database not ready (init containers waiting)
- Redis not accessible (check sentinel health)

### Terraform fails during setup

The setup script handles this — choose **install** again from the menu. It cleans up Terraform state and retries.

### Lima VM won't start

```bash
# Check Lima logs
limactl list
limactl logs rwlight

# Delete and recreate
./rwlight-vm delete
./rwlight-vm create
```

### Images not pulling

Verify the GCP key is valid:

```bash
kubectl get secret gcp-registry-key -n backend-services -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
```

If the key is the placeholder, replace `setup/scripts/gcp-key.json` with a real key and re-run the image pull secret creation:

```bash
cd setup/scripts && ./create_image_pull_secret.sh
```

### DNS not resolving

Verify `/etc/hosts` entries match your `SUBDOMAIN`:

```bash
grep local.runwhen.com /etc/hosts
```

### Mimir monolithic service name

After first deployment, verify the service name:

```bash
kubectl get svc -n mimir | grep monolithic
```

If the service name differs from `mimir-monolithic`, update the cortex-tenant configs and `CORTEX_QUERY_URL`.

---

## Quick Reference

| Item | Value |
|------|-------|
| Default SUBDOMAIN | Set in `setup/vars.env` |
| Kubeconfig | `/mnt/k3s-disk/k3s-dev-platform-kubeconfig` |
| Vault token | `setup/.vault-token` |
| GCP key | `setup/scripts/gcp-key.json` |
| Gitea admin | `root` / password from `vars.env` |
| MinIO credentials | `minioadmin` / `minioadmin` |
| Redis password | `rwlight-redis-pass` (from `vars.env`) |
| Lima VM defaults | 4 CPU, 10 GiB RAM, 80 GiB disk |
| Target resource budget | ~7.6 GB memory, ~2.2 CPU cores |
