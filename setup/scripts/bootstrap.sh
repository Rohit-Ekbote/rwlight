#!/bin/bash

BRANCH_NAME="main"

if flux check >/dev/null 2>&1; then
  echo "✅ Flux already bootstrapped, skipping bootstrap job."
  exit 0
fi

# Bootstrap Flux
echo "🌊 Bootstrapping Flux..."

# Create Flux bootstrap Job manifest
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flux-bootstrap-sa
  namespace: gitea
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: flux-bootstrap-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: flux-bootstrap-sa
    namespace: gitea
---
apiVersion: batch/v1
kind: Job
metadata:
  name: flux-bootstrap
  namespace: gitea
spec:
  backoffLimit: 0
  template:
    spec:
      serviceAccountName: flux-bootstrap-sa
      restartPolicy: Never
      containers:
        - name: flux-bootstrap
          image: ghcr.io/fluxcd/flux-cli:v2.2.3
          env:
            - name: BRANCH_NAME
              value: "${BRANCH_NAME}"
            - name: CLUSTER
              value: "${CLUSTER}"
            - name: GITEA_TOKEN
              valueFrom:
                secretKeyRef:
                  name: gitea-bootstrap-token
                  key: token
            - name: GITEA_REPO_URL
              valueFrom:
                secretKeyRef:
                  name: gitea-bootstrap-token
                  key: git-url
          command:
            - sh
            - -c
            - |
              echo "⏳ Bootstrapping Flux from \$GITEA_REPO_URL..."
              flux bootstrap git \
                --url="\$GITEA_REPO_URL" \
                --branch="\$BRANCH_NAME" \
                --path=clusters/rdebug-pc \
                --token-auth \
                --username=root \
                --password="\$GITEA_TOKEN" \
                --allow-insecure-http=true
EOF

# Wait for job to complete (timeout after 15m — QEMU emulation is slow)
kubectl wait --for=condition=complete --timeout=900s job/flux-bootstrap -n gitea || {
  echo "❌ Job failed or timed out"
  kubectl logs job/flux-bootstrap -n gitea
  exit 1
}

# Show logs after completion
kubectl logs -f job/flux-bootstrap -n gitea

kubectl delete job -n gitea flux-bootstrap
kubectl delete clusterrolebinding flux-bootstrap-admin
kubectl delete serviceaccount -n gitea flux-bootstrap-sa
