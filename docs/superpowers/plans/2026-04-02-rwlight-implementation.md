# rwlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a resource-optimized RunWhen platform setup targeting 4 CPU / 8 GB RAM VMs by modifying Flux manifests, consolidating infrastructure, and adding macOS Lima VM support.

**Architecture:** Fork the RWDev repo (enhancements-8tq) into the rwlight worktree, then apply five changes: Mimir distributed→monolithic, 3 Redis→1 shared sentinel, ingress 2→1 replica, right-size all resources, and add a Lima VM tool for macOS.

**Tech Stack:** k3s, Flux CD, Kustomize, Helm, Lima (macOS), Bash

**Source repo:** `/Users/rohitekbote/wd/code/github.com/runwhen/worktrees/enhancements-8tq`
**Target repo:** `/Users/rohitekbote/emdash-projects/worktrees/brainstorm-41w`

---

### Task 1: Bootstrap rwlight repo from RWDev source

**Files:**
- Copy from source: `setup/`, `tf/`, `flux/`, `Dockerfile`, `CLAUDE.md`

This task copies the base RWDev files into the rwlight worktree so subsequent tasks can modify them in place.

- [ ] **Step 1: Copy source files into rwlight worktree**

```bash
cd /Users/rohitekbote/emdash-projects/worktrees/brainstorm-41w
# Copy the three pillars + supporting files
cp -r /Users/rohitekbote/wd/code/github.com/runwhen/worktrees/enhancements-8tq/setup .
cp -r /Users/rohitekbote/wd/code/github.com/runwhen/worktrees/enhancements-8tq/tf .
cp -r /Users/rohitekbote/wd/code/github.com/runwhen/worktrees/enhancements-8tq/flux .
cp /Users/rohitekbote/wd/code/github.com/runwhen/worktrees/enhancements-8tq/Dockerfile .
cp /Users/rohitekbote/wd/code/github.com/runwhen/worktrees/enhancements-8tq/CLAUDE.md .
cp /Users/rohitekbote/wd/code/github.com/runwhen/worktrees/enhancements-8tq/mount_disk.md .
```

- [ ] **Step 2: Verify directory structure**

```bash
ls -la setup/ tf/ flux/ Dockerfile CLAUDE.md
```

Expected: All directories and files exist.

- [ ] **Step 3: Commit baseline**

```bash
git add setup/ tf/ flux/ Dockerfile CLAUDE.md mount_disk.md
git commit -m "feat: bootstrap rwlight from RWDev source (enhancements-8tq)"
```

---

### Task 2: Mimir distributed to monolithic

**Files:**
- Modify: `flux/infrastructure/mimir/helm-mimir.yaml` — replace distributed HelmRelease with monolithic
- Modify: `flux/infrastructure/mimir/kustomization.yaml` — remove helm-consul.yaml reference
- Delete: `flux/infrastructure/mimir/helm-consul.yaml` — consul no longer needed
- Modify: `flux/infrastructure/mimir/mimir-tenant.yaml` — repoint target from `mimir-nginx` to `mimir`
- Modify: `flux/infrastructure/runner-system/mimir/runner-mimir-tenant-cm.yaml` — repoint target from `mimir-nginx` to `mimir`
- Modify: `flux/apps/backend-services/kustomization.yaml` — update `CORTEX_QUERY_URL`
- Modify: `flux/infrastructure/mimir/helm-grafana.yaml` — add Mimir datasource pointing to monolithic

- [ ] **Step 1: Replace helm-mimir.yaml with monolithic configuration**

Replace the entire contents of `flux/infrastructure/mimir/helm-mimir.yaml` with:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: mimir
  namespace: mimir
spec:
  releaseName: mimir
  chart:
    spec:
      version: 5.7.0
      chart: mimir-distributed
      sourceRef:
        kind: HelmRepository
        name: grafana
        namespace: flux-system
  install:
    timeout: 20m
  upgrade:
    timeout: 20m
  interval: 5m
  values:
    installCRDs: false
    serviceAccount:
      create: true
      name: mimir-sa

    # Run all components in a single process
    mimir:
      structuredConfig:
        server:
          http_listen_port: 8080

        api:
          prometheus_http_prefix: "/prometheus"

        multitenancy_enabled: false

        activity_tracker: {}
        compactor: {}

        common:
          storage:
            backend: s3
            s3:
              access_key_id: ${s3_access_key_id}
              bucket_name: ${mimir_bucket_name}
              endpoint: ${s3_endpoint}
              secret_access_key: ${s3_secret_access_key}
              insecure: true

        alertmanager_storage:
          storage_prefix: alertmanager

        ruler_storage:
          storage_prefix: ruler

        ingester:
          ring:
            replication_factor: 1
            kvstore:
              store: memberlist

        alertmanager:
          enable_api: true
          external_url: '/api/prom/alertmanager'

        blocks_storage:
          storage_prefix: blocks
          bucket_store:
            sync_dir: "/data"
            bucket_index: {}
          tsdb:
            dir: "/data"

        store_gateway:
          sharding_ring:
            kvstore:
              store: memberlist

        ruler:
          alertmanager_url: http://alerts.backend-services.svc.cluster.local
          enable_api: true

    # Disable all distributed components — monolithic mode uses single target
    alertmanager:
      enabled: false
    compactor:
      enabled: false
    distributor:
      enabled: false
    store_gateway:
      enabled: false
    querier:
      enabled: false
    query_frontend:
      enabled: false
    query_scheduler:
      enabled: false
    ruler:
      enabled: false
    ingester:
      enabled: false
    overrides_exporter:
      enabled: false
    rollout_operator:
      enabled: false

    # Disable all caches
    chunks-cache:
      enabled: false
    index-cache:
      enabled: false
    metadata-cache:
      enabled: false
    results-cache:
      enabled: false

    # Disable nginx gateway — monolithic serves directly
    nginx:
      enabled: false

    # Disable minio sub-chart
    minio:
      enabled: false

    # Enable monolithic mode
    deploymentMode: monolithic
    monolithic:
      enabled: true
      replicas: 1
      resources:
        requests:
          cpu: 200m
          memory: 256Mi
        limits:
          cpu: "1"
          memory: 512Mi
      extraArgs:
        log.format: json
      persistentVolume:
        enabled: true
        size: 10Gi
        storageClass: local-path

    memberlist:
      join_members: []
```

- [ ] **Step 2: Remove consul from mimir kustomization**

Edit `flux/infrastructure/mimir/kustomization.yaml` to remove `helm-consul.yaml`:

```yaml
resources:
- namespace.yaml
- helm-mimir.yaml
- mimir-tenant.yaml
- helm-grafana.yaml
- image-pull-sa.yaml
```

- [ ] **Step 3: Delete helm-consul.yaml**

```bash
rm flux/infrastructure/mimir/helm-consul.yaml
```

- [ ] **Step 4: Update mimir-tenant target endpoint**

In `flux/infrastructure/mimir/mimir-tenant.yaml`, change the cortex-tenant ConfigMap target from `http://mimir-nginx/api/v1/push` to `http://mimir-monolithic.mimir.svc.cluster.local:8080/api/v1/push`:

Find and replace in the ConfigMap data section:
```yaml
    target: http://mimir-monolithic.mimir.svc.cluster.local:8080/api/v1/push
```

- [ ] **Step 5: Update runner-mimir-tenant target endpoint**

In `flux/infrastructure/runner-system/mimir/runner-mimir-tenant-cm.yaml`, change the target from `http://mimir-nginx/api/v1/push` to `http://mimir-monolithic.mimir.svc.cluster.local:8080/api/v1/push`:

Find and replace in the ConfigMap data section:
```yaml
    target: http://mimir-monolithic.mimir.svc.cluster.local:8080/api/v1/push
```

- [ ] **Step 6: Update CORTEX_QUERY_URL in backend-services**

In `flux/apps/backend-services/kustomization.yaml`, update the CORTEX_QUERY_URL:

```yaml
  - CORTEX_QUERY_URL="http://mimir-monolithic.mimir.svc.cluster.local:8080/prometheus/api/v1/query"
```

- [ ] **Step 7: Update Grafana datasource to point to monolithic Mimir**

In `flux/infrastructure/mimir/helm-grafana.yaml`, add a datasource:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: grafana
  namespace: mimir
spec:
  releaseName: grafana
  chart:
    spec:
      chart: grafana
      sourceRef:
        kind: HelmRepository
        name: grafana
        namespace: flux-system
  interval: 5m
  values:
    adminUser: runwhen-machine
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
        - name: Mimir
          type: prometheus
          url: http://mimir-monolithic.mimir.svc.cluster.local:8080/prometheus
          access: proxy
          isDefault: true
```

- [ ] **Step 8: Verify monolithic service name**

The `mimir-distributed` Helm chart in monolithic mode creates a service named `mimir-monolithic`. Verify this is correct by checking the chart docs. If the service name differs, update Steps 4-7 accordingly.

**Note:** The actual service name created by the `mimir-distributed` chart in monolithic/deploymentMode may vary. After deployment, run:
```bash
kubectl get svc -n mimir
```
And verify the monolithic service name. If it differs from `mimir-monolithic`, update the cortex-tenant configs and CORTEX_QUERY_URL.

- [ ] **Step 9: Commit**

```bash
git add flux/infrastructure/mimir/ flux/infrastructure/runner-system/mimir/ flux/apps/backend-services/kustomization.yaml
git commit -m "feat: replace Mimir distributed with monolithic mode

Removes 20 pods (microservices, caches, consul) and replaces with
single monolithic Mimir pod. Preserves multi-tenancy, alerting, and
MinIO-backed storage. Saves ~350 Mi memory."
```

---

### Task 3: Redis consolidation — remove separate Redis clusters

**Files:**
- Delete: `flux/apps/llm-gateway/litellm-redis-helm.yaml` — remove litellm Redis
- Modify: `flux/apps/llm-gateway/litellm-proxy-deployment.yaml` — repoint Redis to shared sentinel
- Modify: `flux/apps/backend-services/kustomization.yaml` — update Redis env vars (no change needed for backend services as they already use redis-sentinel-headless)
- Modify: `flux/apps/backend-services/agentfarm-deployment.yaml` — already uses redis-sentinel-headless (no change needed)
- Modify: `flux/apps/backend-services/papi-deployment.yaml` — already uses redis-sentinel-headless (no change needed)

Since the backend services already connect to `redis-sentinel-headless` in the `backend-services` namespace, and the shared Redis stays in `backend-services`, no env var changes are needed for backend services. The changes are:
1. Remove the litellm-redis HelmRelease
2. Update litellm-proxy to connect to the shared Redis sentinel in backend-services namespace

- [ ] **Step 1: Delete litellm-redis HelmRelease**

```bash
rm flux/apps/llm-gateway/litellm-redis-helm.yaml
```

- [ ] **Step 2: Remove litellm-redis-helm.yaml from llm-gateway kustomization**

Read `flux/apps/llm-gateway/kustomization.yaml` (if it exists) or find where litellm-redis-helm.yaml is referenced, and remove it.

If there's no kustomization.yaml in llm-gateway, check `flux/clusters/rdebug-pc/runwhen-llm-gateway.yaml` for the reference.

- [ ] **Step 3: Update litellm-proxy-deployment.yaml Redis config**

In `flux/apps/llm-gateway/litellm-proxy-deployment.yaml`, update the Redis environment variables and init container:

Change the init container `init-wait-for-redis`:
```yaml
      - name: init-wait-for-redis
        image: busybox:1.28
        env:
        - name: REDIS_HOST
          value: "redis-sentinel-headless.backend-services.svc.cluster.local"
        command: ["sh", "-c", "until nslookup $REDIS_HOST; do echo waiting for redis; sleep 2; done"]
```

Change the Redis env vars in the main container:
```yaml
        # Redis configuration — uses shared sentinel in backend-services
        - name: REDIS_HOST
          value: "redis-sentinel-node-0.redis-sentinel-headless.backend-services.svc.cluster.local"
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-sentinel
              key: redis-password
        - name: REDIS_NAMESPACE
          value: "llm-gateway"
```

**Important:** The `secretKeyRef` name changes from `litellm-redis` to `redis-sentinel` — the shared Redis secret. The secret is in `backend-services` namespace but litellm-proxy is in `llm-gateway` namespace. We need to create a copy of the secret or use an ExternalSecret. 

**Alternative approach:** Since Kubernetes secrets are namespace-scoped, we need to either:
a) Copy the redis-sentinel secret to llm-gateway namespace (add a SealedSecret or secret copy mechanism)
b) Or hardcode the Redis password in a ConfigMap (acceptable for dev/demo)
c) Or create a Kustomize secretGenerator that creates the same secret in llm-gateway

For simplicity in dev/demo, create a secret copy in the llm-gateway namespace.

- [ ] **Step 4: Create Redis password secret in llm-gateway namespace**

Create `flux/apps/llm-gateway/shared-redis-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: shared-redis-password
  namespace: llm-gateway
type: Opaque
stringData:
  redis-password: "${redis_sentinel_password}"
```

This secret will be populated via Flux variable substitution from the cluster vars. Add `redis_sentinel_password` to the cluster vars ConfigMap/Secret.

**Alternative (simpler):** If the redis-sentinel Helm chart generates a random password, we need to either:
- Set a fixed password in the redis-sentinel HelmRelease values
- Or use a Kubernetes secret copy controller

The simplest approach: set a fixed Redis password in the HelmRelease.

- [ ] **Step 5: Set fixed Redis password in redis-sentinel HelmRelease**

Edit `flux/apps/backend-services/redis-sentinel-helm.yaml` to add a fixed password:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: redis-sentinel
  namespace: backend-services
spec:
  releaseName: redis-sentinel
  chart:
    spec:
      chart: redis
      version: 18.8.0
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
  interval: 5m
  values:
    global:
      storageClass: local-path
    image:
      repository: bitnamilegacy/redis
    auth:
      password: "${redis_password}"
    master:
      serviceAccount:
        create: false
    replica:
      serviceAccount:
        create: false
    sentinel:
      enabled: true
      automateClusterRecovery: true
      downAfterMilliseconds: 5000
      image:
        repository: bitnamilegacy/redis-sentinel
```

- [ ] **Step 6: Add redis_password to cluster vars**

Edit `flux/clusters/rdebug-pc/runwhen-backend-services.yaml` to include `redis_password` in the postBuild substitution. Also add it to `setup/vars.env`:

Add to `setup/vars.env`:
```
# Redis configs
REDIS_PASSWORD=rwlight-redis-pass
```

The cluster vars ConfigMap or Secret referenced by Flux substitution needs to include `redis_password`. Check the existing substitution mechanism and add the variable.

- [ ] **Step 7: Create shared Redis secret for llm-gateway**

Create `flux/apps/llm-gateway/shared-redis-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: shared-redis-password
  namespace: llm-gateway
type: Opaque
stringData:
  redis-password: "${redis_password}"
```

Update the litellm-proxy deployment to reference this secret:
```yaml
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: shared-redis-password
              key: redis-password
```

- [ ] **Step 8: Handle Gitea Redis replacement**

Gitea's Redis is deployed as a sub-chart of the Gitea Helm release (managed via Terraform, not Flux). The Gitea Helm values need to be updated to disable the built-in Redis cluster and use the external shared Redis.

Since Gitea is deployed via Terraform at `tf/modules/gitea/`, and the Helm chart is installed via `setup/scripts/install_gitea.sh`, we need to:

1. Check `setup/scripts/install_gitea.sh` for how Gitea is installed
2. Add Helm values to disable the redis-cluster sub-chart and point to external Redis

Add these values to the Gitea Helm installation:

```yaml
redis-cluster:
  enabled: false
redis:
  enabled: false
gitea:
  config:
    cache:
      ADAPTER: redis
      HOST: redis+sentinel://redis-sentinel-headless.backend-services.svc.cluster.local:26379/1?masterName=mymaster
    session:
      PROVIDER: redis
      PROVIDER_CONFIG: redis+sentinel://redis-sentinel-headless.backend-services.svc.cluster.local:26379/1?masterName=mymaster
    queue:
      TYPE: redis
      CONN_STR: redis+sentinel://redis-sentinel-headless.backend-services.svc.cluster.local:26379/1?masterName=mymaster
```

**Note:** The exact Gitea Redis connection string format with password needs verification. The format may be:
```
redis+sentinel://:${redis_password}@redis-sentinel-headless.backend-services.svc.cluster.local:26379/1?masterName=mymaster
```

Read `setup/scripts/install_gitea.sh` to understand the current installation method and modify accordingly.

- [ ] **Step 9: Commit**

```bash
git add flux/apps/llm-gateway/ flux/apps/backend-services/redis-sentinel-helm.yaml setup/vars.env
git commit -m "feat: consolidate 3 Redis clusters into 1 shared sentinel

Removes litellm-redis (4 pods) and gitea-redis-cluster (3 pods).
All consumers share the backend-services Redis sentinel cluster
with database isolation (db0=backend, db1=gitea, db2=litellm).
Saves ~180 Mi memory and 7 pods."
```

---

### Task 4: Ingress-nginx scale down

**Files:**
- Modify: `flux/infrastructure/base/ingress-nginx/helm.yaml`

- [ ] **Step 1: Update ingress-nginx HelmRelease**

Edit `flux/infrastructure/base/ingress-nginx/helm.yaml`. Change `replicaCount` from 2 to 1, remove `minAvailable`, and right-size resources:

```yaml
    controller:
      podAnnotations:
        linkerd.io/inject: enabled
      metrics:
        enabled: true
      extraArgs:
        enable-ssl-passthrough: true
      ingressClassResource:
        name: ingress-nginx
        enabled: true
        default: false
        controllerValue: "k8s.io/ingress-nginx"
      replicaCount: 1
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 100m
          memory: 256Mi
      opentelemetry:
        enabled: true
      config:
        otlp-collector-host: grafana-agent-tracing.grafana-agent.svc.cluster.local
        enable-opentelemetry: "true"
        otel-sampler: AlwaysOn
        otel-sampler-ratio: "1.0"
```

Key changes:
- `replicaCount: 2` → `replicaCount: 1`
- Remove `minAvailable: 1` (not needed with 1 replica)
- Memory limit: `1024Mi` → `512Mi`
- CPU limit: `1` → `500m`
- Memory request: `90Mi` → `256Mi` (closer to actual usage of ~320Mi)

- [ ] **Step 2: Commit**

```bash
git add flux/infrastructure/base/ingress-nginx/helm.yaml
git commit -m "feat: scale ingress-nginx from 2 to 1 replica, right-size resources

Single replica sufficient for dev/demo. Saves ~318 Mi memory and 1 pod."
```

---

### Task 5: Right-size resource requests and limits

**Files:**
- Modify: `flux/apps/backend-services/papi-deployment.yaml`
- Modify: `flux/apps/backend-services/usearch-worker-deployment.yaml`
- Modify: `flux/apps/backend-services/usearch-indexer-deployment.yaml`
- Modify: `flux/apps/backend-services/usearch-query-deployment.yaml`
- Modify: `flux/apps/backend-services/usearch-beat-deployment.yaml`
- Modify: `flux/apps/backend-services/agentfarm-deployment.yaml`
- Modify: `flux/apps/backend-services/task-worker-deployment.yaml`
- Modify: `flux/apps/backend-services/task-scheduler-deployment.yaml`
- Modify: `flux/apps/backend-services/sobow-index-deployment.yaml`
- Modify: `flux/apps/backend-services/sobow-search-deployment.yaml`
- Modify: `flux/apps/backend-services/sobrain-deployment.yaml`
- Modify: `flux/apps/backend-services/embedder-deployment.yaml`
- Modify: `flux/apps/backend-services/modelsync-deployment.yaml`
- Modify: `flux/apps/backend-services/activities-deployment.yaml`
- Modify: `flux/apps/backend-services/alerts-deployment.yaml`
- Modify: `flux/apps/backend-services/slackbot-deployment.yaml`
- Modify: `flux/apps/backend-services/webhooks-deployment.yaml`
- Modify: `flux/apps/backend-services/migration-controller.yaml`
- Modify: `flux/apps/backend-services/usearch-migration-controller.yaml`
- Modify: `flux/apps/backend-services/neo4j-helm.yaml`
- Modify: `flux/apps/backend-services/qdrant-helm.yaml`
- Modify: `flux/apps/ui/ui-deployment.yaml`
- Modify: `flux/apps/corestate/install/corestate-deployment.yaml`
- Modify: `flux/apps/worksync-system/worksync-controller-deployment.yaml`
- Modify: `flux/infrastructure/vault/vault.yaml`

This task updates resource requests/limits across all deployments per the spec tables. Each file is a simple find-and-replace of the `resources:` block.

- [ ] **Step 1: Right-size backend-services — heavy consumers**

For each file below, find the `resources:` block in the main container and replace:

**papi-deployment.yaml** (main container):
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

**usearch-worker-deployment.yaml**:
```yaml
        resources:
          requests:
            memory: "512Mi"
            cpu: "100m"
          limits:
            memory: "1536Mi"
            cpu: "500m"
```

**agentfarm-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 512Mi
```

**task-worker-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 50m
            memory: 256Mi
```

**usearch-indexer-deployment.yaml**:
```yaml
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

**usearch-query-deployment.yaml**:
```yaml
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

**sobow-index-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 256Mi
```

**usearch-beat-deployment.yaml**:
```yaml
        resources:
          requests:
            memory: "256Mi"
            cpu: "50m"
          limits:
            memory: "512Mi"
            cpu: "250m"
```

**embedder-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

**modelsync-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

**task-scheduler-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

- [ ] **Step 2: Right-size backend-services — light consumers**

**sobow-search-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

**activities-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 25m
            memory: 64Mi
```

**alerts-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 25m
            memory: 64Mi
```

**slackbot-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 25m
            memory: 64Mi
```

**sobrain-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 25m
            memory: 64Mi
```

**webhooks-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 25m
            memory: 64Mi
```

- [ ] **Step 3: Right-size migration controllers and databases**

**migration-controller.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

**usearch-migration-controller.yaml**:
```yaml
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

**neo4j-helm.yaml** — update the Helm values resources section:
```yaml
    neo4j:
      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: 500m
          memory: 1Gi
```

**qdrant-helm.yaml** — update the Helm values resources section:
```yaml
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

- [ ] **Step 4: Right-size infrastructure services**

**ui-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 128Mi
```

**corestate-deployment.yaml** (in `flux/apps/corestate/install/`):
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 64Mi
```

**worksync-controller-deployment.yaml**:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 128Mi
          requests:
            cpu: 25m
            memory: 32Mi
```

**vault.yaml** (StatefulSet in `flux/infrastructure/vault/`) — find the main vault container resources block:
```yaml
        resources:
          limits:
            cpu: 250m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 64Mi
```

- [ ] **Step 5: Right-size Flux controllers**

Flux controllers are managed by `flux bootstrap` and live in `flux-system` namespace. To right-size them, create a patch file.

Create `flux/clusters/rdebug-pc/flux-system-patches.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helm-controller
  namespace: flux-system
spec:
  template:
    spec:
      containers:
      - name: manager
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 512Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kustomize-controller
  namespace: flux-system
spec:
  template:
    spec:
      containers:
      - name: manager
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 512Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: source-controller
  namespace: flux-system
spec:
  template:
    spec:
      containers:
      - name: manager
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 512Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-controller
  namespace: flux-system
spec:
  template:
    spec:
      containers:
      - name: manager
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 512Mi
```

Then add a Kustomization in the cluster to apply these patches. Add to `flux/clusters/rdebug-pc/infrastructure.yaml`:

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system-resource-patches
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/rdebug-pc
  prune: false
  sourceRef:
    kind: GitRepository
    name: flux-system
  patches:
    - target:
        kind: Deployment
        namespace: flux-system
      patch: |
        - op: replace
          path: /spec/template/spec/containers/0/resources
          value:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 250m
              memory: 512Mi
```

**Note:** The exact mechanism for patching Flux controllers depends on how `flux bootstrap` was configured. An alternative approach is to pass `--resource-limits` flags during bootstrap. If the patch approach doesn't work, the Flux controller resources can be manually adjusted post-bootstrap via `kubectl set resources`.

- [ ] **Step 6: Verify all changes**

Run a quick grep to make sure no deployment still has outsized limits:

```bash
grep -r "memory: 8Gi\|memory: 4Gi\|memory: 2Gi" flux/apps/ flux/infrastructure/
```

Expected: No matches (all 8Gi/4Gi/2Gi limits should have been reduced).

Exceptions: Some Helm chart values may still have large defaults — those are controlled by Helm, not our manifests.

- [ ] **Step 6: Commit**

```bash
git add flux/apps/ flux/infrastructure/vault/
git commit -m "feat: right-size resource requests/limits for all workloads

Reduces total CPU requests from 7,875m to ~2,200m and memory requests
from 15,523 Mi to ~4,500 Mi. Targets 55% utilization on 4 CPU / 8 GB VM."
```

---

### Task 6: Lima VM tool for macOS

**Files:**
- Create: `lima/rwlight.yaml` — Lima VM template
- Create: `rwlight-vm` — CLI script for VM lifecycle

- [ ] **Step 1: Create Lima VM template**

Create `lima/rwlight.yaml`:

```yaml
# Lima VM template for rwlight — lightweight RunWhen platform
# Usage: limactl create --name=rwlight lima/rwlight.yaml

# Always use AMD64 to match RunWhen container image architecture
arch: x86_64

# Use Rosetta for near-native AMD64 performance on Apple Silicon
rosetta:
  enabled: true
  binfmt: true

images:
  - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    arch: "x86_64"

# Default resources — override via rwlight-vm flags
cpus: 4
memory: "10GiB"
disk: "80GiB"

# Mount project directory read-write into the VM
mounts:
  - location: "~"
    writable: true
  - location: "/tmp/lima"
    writable: true

# Forward ingress ports from Mac host to VM
portForwards:
  - guestPort: 80
    hostPort: 80
  - guestPort: 443
    hostPort: 443
  - guestPort: 6443
    hostPort: 6443

# Provision Docker inside the VM (required for k3s setup container)
provision:
  - mode: system
    script: |
      #!/bin/bash
      set -eux -o pipefail

      # Install Docker if not present
      if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker "${LIMA_CIDATA_USER}"
      fi

      # Install required tools
      apt-get update -qq
      apt-get install -y -qq curl git jq

      echo "Lima VM provisioning complete. Docker and tools installed."

containerd:
  system: false
  user: false
```

- [ ] **Step 2: Create rwlight-vm CLI script**

Create `rwlight-vm` at the repo root:

```bash
#!/usr/bin/env bash
set -euo pipefail

# rwlight-vm — Lima VM lifecycle management for rwlight on macOS
# Usage: rwlight-vm <command> [flags]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIMA_TEMPLATE="${SCRIPT_DIR}/lima/rwlight.yaml"

# Defaults
VM_NAME="rwlight"
VM_CPUS=4
VM_MEMORY=10
VM_DISK=80

usage() {
    cat <<EOF
Usage: rwlight-vm <command> [flags]

Commands:
  create    Create a new Lima VM for rwlight
  delete    Delete the rwlight Lima VM
  status    Show VM status and connection details
  ssh       SSH into the VM
  start     Start a stopped VM
  stop      Stop the VM

Create flags:
  --cpus <n>      Number of CPU cores (default: ${VM_CPUS})
  --memory <n>    Memory in GiB (default: ${VM_MEMORY})
  --disk <n>      Disk size in GiB (default: ${VM_DISK})
  --name <name>   VM name (default: ${VM_NAME})

Examples:
  rwlight-vm create
  rwlight-vm create --cpus 6 --memory 12 --disk 100
  rwlight-vm ssh
  rwlight-vm status
  rwlight-vm delete
EOF
}

check_lima() {
    if ! command -v limactl &> /dev/null; then
        echo "ERROR: Lima is not installed."
        echo "Install with: brew install lima"
        exit 1
    fi
}

check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo "ERROR: rwlight-vm is only needed on macOS."
        echo "On Linux, run setup.sh directly."
        exit 1
    fi
}

cmd_create() {
    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cpus)   VM_CPUS="$2"; shift 2 ;;
            --memory) VM_MEMORY="$2"; shift 2 ;;
            --disk)   VM_DISK="$2"; shift 2 ;;
            --name)   VM_NAME="$2"; shift 2 ;;
            *)        echo "Unknown flag: $1"; usage; exit 1 ;;
        esac
    done

    if ! [[ -f "${LIMA_TEMPLATE}" ]]; then
        echo "ERROR: Lima template not found at ${LIMA_TEMPLATE}"
        exit 1
    fi

    # Check if VM already exists
    if limactl list --json | jq -e ".[] | select(.name == \"${VM_NAME}\")" > /dev/null 2>&1; then
        echo "ERROR: VM '${VM_NAME}' already exists."
        echo "Use 'rwlight-vm delete' to remove it first, or 'rwlight-vm start' to start it."
        exit 1
    fi

    echo "Creating Lima VM '${VM_NAME}'..."
    echo "  CPUs:   ${VM_CPUS}"
    echo "  Memory: ${VM_MEMORY} GiB"
    echo "  Disk:   ${VM_DISK} GiB"
    echo ""

    limactl create \
        --name="${VM_NAME}" \
        --cpus="${VM_CPUS}" \
        --memory="${VM_MEMORY}GiB" \
        --disk="${VM_DISK}GiB" \
        --tty=false \
        "${LIMA_TEMPLATE}"

    limactl start "${VM_NAME}"

    # Get VM IP
    local vm_ip
    vm_ip=$(limactl shell "${VM_NAME}" hostname -I | awk '{print $1}')

    echo ""
    echo "Lima VM '${VM_NAME}' created successfully."
    echo ""
    echo "VM Details:"
    echo "  Name:       ${VM_NAME}"
    echo "  CPUs:       ${VM_CPUS}"
    echo "  Memory:     ${VM_MEMORY} GiB"
    echo "  Disk:       ${VM_DISK} GiB"
    echo "  IP:         ${vm_ip}"
    echo "  SSH:        limactl shell ${VM_NAME}"
    echo "  OS:         Ubuntu 24.04 (AMD64 via Rosetta)"
    echo ""
    echo "To set up the RunWhen platform:"
    echo "  limactl shell ${VM_NAME}"
    echo "  cd $(pwd)"
    echo "  ./setup/setup.sh"
}

cmd_delete() {
    echo "Deleting Lima VM '${VM_NAME}'..."
    limactl delete --force "${VM_NAME}" 2>/dev/null || true
    echo "VM '${VM_NAME}' deleted."
}

cmd_status() {
    if ! limactl list --json | jq -e ".[] | select(.name == \"${VM_NAME}\")" > /dev/null 2>&1; then
        echo "VM '${VM_NAME}' does not exist."
        echo "Use 'rwlight-vm create' to create it."
        exit 1
    fi

    limactl list | head -1
    limactl list | grep "${VM_NAME}"

    local status
    status=$(limactl list --json | jq -r ".[] | select(.name == \"${VM_NAME}\") | .status")

    if [[ "${status}" == "Running" ]]; then
        local vm_ip
        vm_ip=$(limactl shell "${VM_NAME}" hostname -I 2>/dev/null | awk '{print $1}')
        echo ""
        echo "SSH:  limactl shell ${VM_NAME}"
        echo "IP:   ${vm_ip}"
    fi
}

cmd_ssh() {
    limactl shell "${VM_NAME}"
}

cmd_start() {
    echo "Starting Lima VM '${VM_NAME}'..."
    limactl start "${VM_NAME}"
    echo "VM '${VM_NAME}' started."
}

cmd_stop() {
    echo "Stopping Lima VM '${VM_NAME}'..."
    limactl stop "${VM_NAME}"
    echo "VM '${VM_NAME}' stopped."
}

# Main
check_macos
check_lima

case "${1:-}" in
    create)  shift; cmd_create "$@" ;;
    delete)  cmd_delete ;;
    status)  cmd_status ;;
    ssh)     cmd_ssh ;;
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    -h|--help|help) usage ;;
    *)
        echo "ERROR: Unknown command '${1:-}'"
        echo ""
        usage
        exit 1
        ;;
esac
```

- [ ] **Step 3: Make rwlight-vm executable**

```bash
chmod +x rwlight-vm
```

- [ ] **Step 4: Verify script parses correctly**

```bash
bash -n rwlight-vm
echo $?
```

Expected: `0` (no syntax errors)

- [ ] **Step 5: Commit**

```bash
git add lima/rwlight.yaml rwlight-vm
git commit -m "feat: add rwlight-vm CLI and Lima template for macOS support

Provides Lima VM lifecycle management (create/delete/start/stop/ssh/status)
for running rwlight on macOS. Always uses AMD64 VM via Rosetta to match
RunWhen container image architecture. Defaults: 4 CPU, 10 GiB RAM, 80 GiB disk."
```

---

### Task 7: Update setup defaults and README

**Files:**
- Modify: `setup/vars.env` — add rwlight-specific notes
- Modify: `README.md` — update with rwlight setup instructions

- [ ] **Step 1: Update setup/vars.env**

Add a comment block at the top of `setup/vars.env`:

```bash
# rwlight — Lightweight RunWhen Platform
# Target: 4 CPU / 8 GB RAM VMs (or Lima VM on macOS)
#
# For macOS: run ./rwlight-vm create first, then SSH into the VM
# For Linux: run ./setup/setup.sh directly

# Global configs
SUBDOMAIN=
DOMAIN=local.runwhen.com
ARTIFACT_REGISTRY_PATH=us-docker.pkg.dev/runwhen-nonprod-shared/private-platform-images/

# Below settings are defaults
CLUSTER=dev-platform
NETWORK=rwdev-network

# Gitea configs
GITEA_ADMIN_USER=root
GITEA_ADMIN_PASS=adminpass123
GITEA_ADMIN_EMAIL=admin@local.runwhen.com

# S3 configs
S3_ENDPOINT=minio.minio.svc.cluster.local:9000
S3_ACCESS_KEY_ID=minioadmin
S3_SECRET_ACCESS_KEY=minioadmin

# mimir configs
MIMIR_BUCKET_NAME=runwhen-local-mimir-00

# Redis configs
REDIS_PASSWORD=rwlight-redis-pass

# Do not modify
VERSION=0.0.1
KUBECONFIG=/mnt/k3s-disk/k3s-dev-platform-kubeconfig
```

- [ ] **Step 2: Update README.md**

Replace the contents of `README.md`:

```markdown
# rwlight

Lightweight RunWhen platform for small VMs (4 CPU / 8 GB RAM).

## Quick Start

### macOS

```bash
# Install Lima
brew install lima

# Create VM (defaults: 4 CPU, 10 GiB RAM, 80 GiB disk)
./rwlight-vm create

# SSH into the VM
./rwlight-vm ssh

# Inside the VM, run setup
cd /path/to/rwlight
./setup/setup.sh
```

### Linux

```bash
# Run setup directly (requires 4+ CPU, 8+ GB RAM)
./setup/setup.sh
```

## VM Management (macOS only)

```bash
./rwlight-vm create              # Create VM
./rwlight-vm create --cpus 6 --memory 12  # Custom resources
./rwlight-vm ssh                 # SSH into VM
./rwlight-vm status              # Check VM status
./rwlight-vm stop                # Stop VM
./rwlight-vm start               # Start stopped VM
./rwlight-vm delete              # Delete VM
```

## What's different from RWDev

rwlight is a resource-optimized variant of RWDev targeting smaller VMs:

- Mimir runs in monolithic mode (1 pod instead of 20)
- Single shared Redis sentinel cluster (3 pods instead of 10)
- Ingress-nginx scaled to 1 replica
- All workloads right-sized for actual usage
- macOS support via Lima VM

See `docs/superpowers/specs/2026-04-02-rwlight-design.md` for the full design.
```

- [ ] **Step 3: Commit**

```bash
git add setup/vars.env README.md
git commit -m "feat: update setup defaults and README for rwlight

Adds Redis password config, rwlight version, and comprehensive
README with quick start instructions for macOS and Linux."
```

---

### Task 8: Verification checklist

This task is a manual verification to run after deploying rwlight to a test VM.

- [ ] **Step 1: Deploy to a test VM and verify pods**

```bash
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

Expected: No pods in Pending, CrashLoopBackOff, or Error state.

- [ ] **Step 2: Verify resource usage fits in budget**

```bash
kubectl top nodes
kubectl top pods -A --sort-by=memory
```

Expected: Total memory usage < 7.6 GB, CPU usage < 4 cores.

- [ ] **Step 3: Verify Mimir monolithic is functional**

```bash
# Check Mimir pod is running
kubectl get pods -n mimir -l app.kubernetes.io/component=monolithic

# Test metrics query via CORTEX_QUERY_URL
kubectl exec -n backend-services deploy/papi -- curl -s "http://mimir-monolithic.mimir.svc.cluster.local:8080/prometheus/api/v1/query?query=up"
```

Expected: Valid JSON response with metric data.

- [ ] **Step 4: Verify Redis is shared correctly**

```bash
# Check sentinel is running
kubectl get pods -n backend-services -l app.kubernetes.io/name=redis-sentinel

# Verify litellm can reach Redis
kubectl logs -n llm-gateway deploy/litellm-proxy | grep -i redis
```

Expected: 3 Redis sentinel pods running, litellm connected without errors.

- [ ] **Step 5: Verify ingress routes work**

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check all ingress resources have addresses
kubectl get ingress -A
```

Expected: 1 ingress-nginx pod running, all 12 ingresses have assigned addresses.

- [ ] **Step 6: Verify UI is accessible**

```bash
curl -k https://app.${SUBDOMAIN}.${DOMAIN}
```

Expected: HTML response from the UI.
