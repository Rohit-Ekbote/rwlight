# rwlight: Lightweight RunWhen Platform for Small VMs

**Date:** 2026-04-02
**Target:** 4 CPU / 8 GB RAM VMs
**Approach:** Right-size and consolidate — same architecture, aggressive resource tuning

## Overview

rwlight is a resource-optimized variant of the RWDev platform (enhancements-8tq). It maintains the same architecture (k3s + Flux CD + Gitea + Vault + Terraform) but reduces resource consumption from ~12.5 GB to ~7 GB through three strategies:

1. **Replace** Mimir distributed stack (20 pods) with Mimir monolithic mode (1 pod)
2. **Consolidate** 3 Redis deployments (10 pods) into 1 shared Redis Sentinel cluster (3 pods)
3. **Right-size** resource requests/limits across all workloads to match actual usage

**Use cases:** Developer inner-loop (running/debugging platform services) and demo/testing.

## Current State (RWDev on 16 CPU / 16 GB VM)

- ~98 pods across 15 namespaces
- 12.5 GB actual memory usage, 97% of memory requests consumed
- 3 separate Redis clusters (10 pods)
- Full Mimir distributed stack (20 pods)
- 2 ingress-nginx replicas
- Many workloads request 5-10x their actual usage

## Target State (rwlight on 4 CPU / 8 GB VM)

- ~67 pods (-31)
- ~7.1 GB estimated actual memory usage
- ~900 Mi headroom for OS and burst
- CPU requests: ~2,200m (55% of 4 CPU)
- Memory requests: ~4,500 Mi (55% of 8 GB)

---

## Change 1: Mimir Distributed to Monolithic

### Rationale

The current Mimir distributed deployment runs 20 pods (distributor, ingester, querier, query-frontend, query-scheduler x2, ruler, compactor, store-gateway, alertmanager, nginx, rollout-operator, overrides-exporter, 4x memcached caches, consul, grafana, 2x cortex-tenant proxies) consuming ~656 Mi. Mimir supports a monolithic mode that runs all components in a single process.

### Requirements preserved

- **Multi-tenancy:** `X-Scope-OrgID` header for workspace-level isolation on reads and writes
- **Alerting:** Built-in ruler and alertmanager for recording/alerting rule evaluation
- **Data retention:** MinIO-backed long-term storage (same as current)
- **API compatibility:** Same Prometheus-compatible query API, same remote_write endpoint

### Design

| Component | Current | rwlight |
|-----------|---------|---------|
| Mimir core | 17 pods (microservices) | 1 pod (monolithic StatefulSet) |
| Memcached caches | 4 pods | 0 (in-process caching) |
| Consul | 1 pod | 0 (no service discovery needed) |
| cortex-tenant (internal) | 1 pod | 1 pod (unchanged) |
| runner-mimir-tenant (external) | 1 pod | 1 pod (unchanged, mTLS ingress preserved) |
| Grafana | 1 pod | 1 pod (unchanged, datasource repointed) |
| **Total** | **24 pods** | **4 pods** |

### Configuration

- Deploy Mimir with `-target=all` flag (monolithic mode)
- Storage backend: MinIO at `minio.minio.svc.cluster.local:9000` (unchanged)
- Bucket: `runwhen-local-mimir-00` (unchanged)
- Alertmanager configured to send to `http://alerts.backend-services.svc.cluster.local` (unchanged)
- PAPI `CORTEX_QUERY_URL` repointed to `http://mimir.mimir.svc.cluster.local:8080/prometheus/api/v1`
- cortex-tenant proxies repointed to `http://mimir.mimir.svc.cluster.local:8080/api/v1/push`

### Resource allocation

| | Request | Limit |
|--|---------|-------|
| CPU | 200m | 1 |
| Memory | 256Mi | 512Mi |
| Storage | 10Gi PVC (WAL/local cache) |

### Estimated savings

~250-350 Mi memory, 20 fewer pods, significant scheduling overhead reduction.

---

## Change 2: Redis Consolidation

### Rationale

Three separate Redis deployments serve isolated consumers with no cross-talk. For dev/demo, a single HA cluster with database-level isolation is sufficient.

### Current state

| Cluster | Namespace | Topology | Pods | Auth | Consumers |
|---------|-----------|----------|------|------|-----------|
| redis-sentinel | backend-services | Sentinel, 3 nodes | 3 | Password | All backend services |
| gitea-redis-cluster | gitea | Cluster mode, 3 nodes | 3 | No auth | Gitea |
| litellm-redis | llm-gateway | Master + 3 replicas | 4 | Password | litellm-proxy |

### Design

- **Single Redis Sentinel cluster** (3 pods): 1 master + 2 replicas with sentinel sidecars
- **Helm chart:** `bitnami/redis` with sentinel enabled (same chart as current backend-services Redis)
- **Namespace:** `backend-services` (largest consumer, minimizes config changes)
- **Database isolation:** db0 = backend-services, db1 = Gitea, db2 = litellm
- **Auth:** Password-protected, single shared secret
- **Persistence:** AOF enabled, 8Gi PVC

### Consumer config changes

| Consumer | Current config | New config |
|----------|---------------|------------|
| Backend services (PAPI, activities, alerts, task-worker, etc.) | `CACHE_TYPE=redis-sentinel`, `SENTINEL_HOSTS=redis-sentinel-headless` | No change to type/hosts (same sentinel topology), add `REDIS_DB=0` |
| Agentfarm | `REDIS_SENTINEL_HOSTS`, `REDIS_SENTINEL_PASSWORD` | Repoint to shared sentinel, `REDIS_DB=0` |
| Task-worker | `REDIS_HOST=redis-sentinel-node-0...` (direct master) | Repoint to shared Redis host |
| Gitea | Sub-chart Redis (cluster mode, no auth) | Helm values override: external Redis, sentinel mode, password, db1 |
| litellm-proxy | `REDIS_HOST=litellm-redis-master`, password | Repoint to shared sentinel, `REDIS_DB=2` |

### Removed components

- `gitea-redis-cluster` StatefulSet (3 pods) — replaced by shared Redis db1
- `litellm-redis-master` StatefulSet (1 pod) — replaced by shared Redis db2
- `litellm-redis-replicas` StatefulSet (3 pods) — replaced by shared Redis db2

### Risk

All services share one Redis process. A runaway consumer could impact others. Acceptable for dev/demo — not suitable for production.

### Estimated savings

7 fewer pods, ~180 Mi memory.

---

## Change 3: Ingress NGINX Scale Down

### Rationale

2 replicas serve 12 ingress routes on a single-node dev cluster. 1 replica handles the load with CPU/memory to spare.

### Design

- Scale `ingress-nginx-controller` deployment from 2 replicas to 1
- Right-size resources: 100m/256Mi request, 500m/512Mi limit

### Estimated savings

~318 Mi memory, 1 fewer pod.

---

## Change 4: Right-Sized Resource Requests & Limits

### Rationale

Many workloads request 5-10x their actual usage. Migration controllers have 8Gi limits for idle pods. UI requests 1Gi but uses 161Mi. Right-sizing frees memory for scheduling without impacting actual workload performance.

### Backend Services

| Service | Current Req (CPU/Mem) | Current Lim (CPU/Mem) | Actual Usage (CPU/Mem) | Proposed Req (CPU/Mem) | Proposed Lim (CPU/Mem) |
|---------|----------------------|----------------------|----------------------|----------------------|----------------------|
| usearch-worker | 500m / 1Gi | 2 / 2Gi | 2m / 1,565Mi | 100m / 512Mi | 500m / 1.5Gi |
| agentfarm | 1 / 1Gi | 2 / 2Gi | 2m / 754Mi | 100m / 512Mi | 500m / 1Gi |
| task-worker | 100m / 512Mi | 2 / 2Gi | 2m / 489Mi | 50m / 256Mi | 500m / 1Gi |
| usearch-indexer | 500m / 512Mi | 1 / 1Gi | 4m / 339Mi | 100m / 256Mi | 500m / 512Mi |
| usearch-query | 500m / 512Mi | 1 / 1Gi | 4m / 337Mi | 100m / 256Mi | 500m / 512Mi |
| sobow-index | 100m / 256Mi | 1 / 1536Mi | 1m / 320Mi | 50m / 256Mi | 500m / 512Mi |
| usearch-beat | 100m / 256Mi | 500m / 512Mi | 0m / 311Mi | 50m / 256Mi | 250m / 512Mi |
| embedder | 300m / 64Mi | 1 / 1Gi | 3m / 296Mi | 50m / 128Mi | 500m / 512Mi |
| papi | 100m / 64Mi | 2 / 1Gi | 2m / 258Mi | 50m / 128Mi | 500m / 512Mi |
| sobow-search | 100m / 32Mi | 1 / 512Mi | 2m / 234Mi | 50m / 128Mi | 500m / 512Mi |
| modelsync | 100m / 512Mi | 1 / 2Gi | 4m / 226Mi | 50m / 128Mi | 500m / 512Mi |
| task-scheduler | 100m / 64Mi | 1 / 1Gi | 1m / 180Mi | 50m / 128Mi | 500m / 512Mi |
| qdrant | 100m / 128Mi | 1 / 1Gi | 1m / 192Mi | 50m / 128Mi | 500m / 512Mi |
| migration-controller | 100m / 256Mi | 1 / 8Gi | idle | 50m / 128Mi | 500m / 512Mi |
| usearch-migration-ctrl | 100m / 256Mi | 1 / 8Gi | idle | 50m / 128Mi | 500m / 512Mi |
| neo4j | 1 / 2Gi | 1 / 2Gi | Pending | 200m / 512Mi | 500m / 1Gi |
| activities | 50m / 32Mi | 1 / 512Mi | <5m / <100Mi | 25m / 64Mi | 250m / 256Mi |
| alerts | 100m / 64Mi | 1 / 512Mi | <5m / <100Mi | 25m / 64Mi | 250m / 256Mi |
| slackbot | 100m / 64Mi | 1 / 512Mi | <5m / <100Mi | 25m / 64Mi | 250m / 256Mi |
| sobrain | 50m / 32Mi | 1 / 512Mi | <5m / <100Mi | 25m / 64Mi | 250m / 256Mi |
| webhooks | 10m / 64Mi | 1 / 1Gi | <5m / <100Mi | 25m / 64Mi | 250m / 256Mi |

### Infrastructure

| Service | Current Req (CPU/Mem) | Actual Usage (CPU/Mem) | Proposed Req (CPU/Mem) | Proposed Lim (CPU/Mem) |
|---------|----------------------|----------------------|----------------------|----------------------|
| UI | 200m / 1Gi | 0m / 161Mi | 50m / 128Mi | 250m / 512Mi |
| corestate-controller | 200m / 1Gi | 5m / 58Mi | 50m / 64Mi | 250m / 256Mi |
| Flux controllers (x4) | 100m / 64Mi each | 1-67m / 115-414Mi each | 50m / 64Mi each | 250m / 512Mi each |
| ingress-nginx (1 replica) | 100m / 90Mi | 30m / 320Mi | 100m / 256Mi | 500m / 512Mi |
| Vault | 100m / 1Gi | 3m / 70Mi | 50m / 64Mi | 250m / 256Mi |
| worksync-controller | 100m / 128Mi | 2m / 26Mi | 25m / 32Mi | 250m / 128Mi |
| runner-control | none | 1m / 14Mi | 25m / 32Mi | 250m / 128Mi |

### Aggregate impact

| Metric | Current | rwlight |
|--------|---------|---------|
| Total CPU requests | 7,875m | ~2,200m |
| Total memory requests | 15,523 Mi | ~4,500 Mi |
| CPU % of capacity | 49% of 16 CPU | 55% of 4 CPU |
| Memory % of capacity | 97% of 16 GB | 55% of 8 GB |

---

## Pod Count Summary

| Namespace | Current | rwlight | Delta |
|-----------|---------|---------|-------|
| backend-services | 31 | 24 | -7 |
| mimir | 20 | 4 | -16 |
| llm-gateway | 9 | 2 | -7 |
| gitea | 5 | 2 | -3 |
| ingress-nginx | 2 | 1 | -1 |
| shared-redis (new, in backend-services) | 0 | 3 | +3 |
| flux-system | 5 | 5 | 0 |
| cert-manager | 4 | 4 | 0 |
| corestate | 5 | 5 | 0 |
| vault | 3 | 3 | 0 |
| ui | 1 | 1 | 0 |
| minio | 1 | 1 | 0 |
| postgres-operator | 2 | 2 | 0 |
| runner-system | 1 | 1 | 0 |
| worksync-system | 1 | 1 | 0 |
| kube-system | 8 | 8 | 0 |
| **Total** | **~98** | **~67** | **-31** |

## Memory Budget (8 GB target)

| Category | Estimated Actual Usage |
|----------|----------------------|
| Backend services (right-sized, usearch-worker at 1.5Gi limit) | ~5,000 Mi |
| Mimir monolithic + proxies + grafana | ~400 Mi |
| Shared Redis sentinel (3 pods) | ~100 Mi |
| Ingress nginx (1 replica) | ~320 Mi |
| Flux controllers (4) | ~700 Mi |
| Gitea + postgres | ~180 Mi |
| Cert-manager | ~200 Mi |
| Corestate | ~120 Mi |
| Vault | ~100 Mi |
| UI | ~160 Mi |
| MinIO | ~180 Mi |
| Postgres operator | ~100 Mi |
| Runner + WorkSync | ~40 Mi |
| kube-system | ~200 Mi |
| **Total** | **~7,800 Mi (~7.6 GB)** |

Headroom: ~400 Mi for OS overhead and burst. Tight but viable for dev/demo. If insufficient, bump VM to 10 GB.

---

## Change 5: macOS Support via Lima VM

### Rationale

k3s is Linux-only. To support MacBook users (both Intel and Apple Silicon), rwlight needs a way to provision a Linux VM on macOS. This should be a separate tool from the platform setup — clean separation of concerns.

### Design

**Two-phase workflow:**

```
[macOS only]                    [Linux or Lima VM]
rwlight-vm create  ──→  VM details (IP, SSH, kubeconfig path)  ──→  setup.sh
```

On Linux laptops, `rwlight-vm` is not needed — `setup.sh` runs directly on the host.

### `rwlight-vm` CLI tool

A standalone script (`rwlight-vm`) that manages Lima VMs for rwlight. It is only used on macOS.

**Commands:**

| Command | Description |
|---------|-------------|
| `rwlight-vm create` | Create a new Lima VM for rwlight |
| `rwlight-vm delete` | Delete the rwlight Lima VM |
| `rwlight-vm status` | Show VM status and connection details |
| `rwlight-vm ssh` | SSH into the VM |
| `rwlight-vm start` | Start a stopped VM |
| `rwlight-vm stop` | Stop the VM |

**`rwlight-vm create` flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `--cpus` | 4 | Number of CPU cores |
| `--memory` | 10 (GiB) | Memory allocation |
| `--disk` | 80 (GiB) | Disk size |
| `--name` | rwlight | VM name |

**`rwlight-vm create` output:**

```
Lima VM 'rwlight' created successfully.

VM Details:
  Name:       rwlight
  CPUs:       4
  Memory:     10 GiB
  Disk:       80 GiB
  IP:         192.168.64.5
  SSH:        limactl shell rwlight
  OS:         Ubuntu 24.04 (ARM64)

To set up the RunWhen platform:
  limactl shell rwlight
  cd /path/to/rwlight
  ./setup/setup.sh
```

### Lima VM template

A Lima YAML template (`lima/rwlight.yaml`) that configures:

- **Base image:** Ubuntu 24.04 LTS (ARM64 or AMD64 auto-detected)
- **Resources:** Configurable CPU/memory/disk (defaults: 4 CPU / 10 GiB / 80 GiB)
- **Mounts:** Project directory mounted read-write into the VM
- **Provisioning:** Pre-install Docker (required for k3s setup container)
- **Port forwarding:** Forward ingress ports (80, 443) from Mac host to VM
- **DNS:** Configure so that `*.local.runwhen.com` subdomains resolve to the VM IP

### Architecture support

The Lima VM always runs **AMD64 Linux** regardless of host Mac architecture. This avoids any multi-arch image requirements — all container images run as AMD64 inside the VM.

- **Apple Silicon (M1/M2/M3/M4):** AMD64 VM via Rosetta emulation (`arch: x86_64`, `rosetta: enabled`). Rosetta runs AMD64 Linux binaries at near-native speed.
- **Intel Mac:** AMD64 VM natively via QEMU.

This means no changes to CI/CD pipelines or container image builds are needed.

### Prerequisites on macOS

- Lima installed (`brew install lima`)
- Docker not required on the Mac host (Docker runs inside the Lima VM)

### Setup script changes

The existing `setup.sh` / `setup-rwdev.sh` scripts remain Linux-focused and do not change. They run inside the Lima VM (or directly on a Linux laptop) as they do today. The only addition is the `rwlight-vm` tool for macOS users.

### Container image architecture

RunWhen platform images are AMD64-only. By always running an AMD64 Linux VM in Lima (with Rosetta on Apple Silicon), all images work without modification. No CI/CD changes needed.

## Repo Changes Required

| Area | Files affected | Nature of change |
|------|---------------|-----------------|
| Mimir config | `flux/infrastructure/mimir/` | Replace mimir-distributed HelmRelease with mimir monolithic config |
| Redis consolidation | `flux/apps/backend-services/kustomization.yaml` | Update Redis env vars for all services, remove redis-sentinel HelmRelease, add shared sentinel HelmRelease |
| Gitea Redis override | Gitea HelmRelease values | Override sub-chart Redis with external shared Redis (host, password, db1) |
| litellm Redis override | litellm HelmRelease values | Override Redis config (shared sentinel host, password, db2) |
| Ingress replica | `flux/infrastructure/base/` or cluster kustomization | Scale ingress-nginx to 1 replica |
| Resource right-sizing | All deployment/statefulset manifests across namespaces | Update requests/limits per tables above |
| Setup defaults | `setup/vars.env` | Add rwlight-specific VM size defaults |
| macOS VM tool | `rwlight-vm` (new script) | Lima VM lifecycle management for macOS users |
| Lima template | `lima/rwlight.yaml` (new file) | VM configuration template with resource defaults |

## What Does NOT Change

- Setup scripts (setup.sh, setup-rwdev.sh, clean-rwdev.sh) — run inside Lima VM on Mac, or directly on Linux
- Terraform modules (Gitea + Vault provisioning)
- Flux CD bootstrap process
- Application container images
- Backend service application code
- Ingress definitions (routes, hosts, TLS, mTLS — only replica count changes)
- Cert-manager, Vault, PostgreSQL, MinIO architecture (only resource tuning)
- CoreState, WorkSync, Runner System architecture

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Shared Redis contention | Low | Medium | Database isolation (db0/1/2), monitor with Redis INFO command |
| Mimir monolithic OOM | Low | High | Conservative memory limit (512Mi), monitor with `kubectl top` |
| Tight memory headroom (~400 Mi) | Medium | Medium | OS typically needs 200-400 Mi. Leaves minimal burst room. If insufficient, bump VM to 10 GB. |
| usearch-worker memory usage | Medium | Low | Set limit to 1.5Gi. Investigate whether 1,565 Mi usage is expected or a leak. |
| Rosetta emulation overhead on Apple Silicon | Low | Low | Lima VM runs AMD64 via Rosetta which is near-native speed. No multi-arch images needed. |
| Lima VM networking | Low | Medium | Port forwarding and DNS for `*.local.runwhen.com` may need manual `/etc/hosts` entries on macOS. |

## Decision: usearch-worker Memory

usearch-worker currently uses 1,565 Mi. The limit is set to 1.5Gi (down from 2Gi) to accommodate actual usage while reducing overcommit. The high memory usage should be investigated separately — it may be a memory leak or expected behavior for vector processing workloads. If it proves to be expected, the 1.5Gi limit is appropriate. If it's a leak, fixing it would free ~500 Mi of headroom.
