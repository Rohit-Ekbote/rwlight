#!/bin/bash

set -o errexit
set -o nounset

kubectl create configmap platform-cluster-cluster-vars -n flux-system \
    --from-literal=artifact_registry_path="${ARTIFACT_REGISTRY_PATH}" \
    --from-literal=domain=$DOMAIN \
    --from-literal=subdomain=$SUBDOMAIN \
    --from-literal=vault_address="http://vault.vault.svc.cluster.local:8200" \
    --from-literal=cluster_name="${CLUSTER}" \
    --from-literal=s3_endpoint="${S3_ENDPOINT}" \
    --from-literal=mimir_bucket_name="${MIMIR_BUCKET_NAME}" \
    --from-literal=is_local='"true"' \
    --dry-run=client -o yaml | kubectl apply -f - --validate=false

kubectl create secret generic platform-cluster-cluster-vars -n flux-system \
    --from-literal=s3_access_key_id="${S3_ACCESS_KEY_ID}" \
    --from-literal=s3_secret_access_key="${S3_SECRET_ACCESS_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f - --validate=false
