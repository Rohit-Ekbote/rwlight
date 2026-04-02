#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Extract vars from query input
# NAME = Cluster Name, the rest explain themselves
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "NAMESPACE=\(.namespace) SECRET_NAME=\(.secret_name)"')"

# Get JWT from vault-sa
JWT=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o=jsonpath='{.data.token}' | base64 -d)

# sleep 3
# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
jq -n --arg jwt "$JWT" '{"jwt":$jwt}'