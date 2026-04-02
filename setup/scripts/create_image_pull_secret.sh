#!/bin/bash

set -o errexit
set -o nounset


for ns in mimir worksync-system ui runner-system llm-gateway corestate backend-services; do

    until kubectl get ns "$ns" >/dev/null 2>&1; do
        echo "Namespace $ns not found. Waiting..."
        sleep 3
    done
    
    kubectl create secret docker-registry gcp-registry-key \
        --docker-server=us-docker.pkg.dev \
        --docker-username=_json_key \
        --docker-password="$(cat gcp-key.json)" \
        --docker-email=runwhen-machine@runwhen.com \
        -n $ns
done
