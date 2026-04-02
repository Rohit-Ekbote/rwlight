#!/bin/bash

# Script to create an admin token for Gitea similar to GitLab's token creation
# This script expects kubectl context to be set to the correct cluster

set -e

eval "$(jq -r '@sh "ADMIN_USERNAME=\(.admin_username) ADMIN_PASSWORD=\(.admin_password) GITEA_URL=\(.gitea_url)"')"

# Function to create admin token via Gitea API
create_admin_token() {
    local gitea_url="$1"
    local username="$2"
    local password="$3"
    local token_name="runwhen-machine-token-$(date +%s)"
    
    # Create token using Gitea API
    token_response=$(jq -n \
        --arg name "$token_name" \
        --argjson scopes '["all"]' \
        '{name: $name, scopes: $scopes}' | \
        curl -s -k -X POST \
        -H "Content-Type: application/json" \
        -u "${username}:${password}" \
        -d @- \
        "${gitea_url}/api/v1/users/${username}/tokens" || echo "failed")
    
    if [ "$token_response" = "failed" ]; then
        echo "Failed to create token" >&2
        exit 1
    fi
    
    # Extract token from response
    echo "DEBUG: token_response=$token_response" >&2
    token=$(echo "$token_response" | jq -r '.sha1')
    
    if [ "$token" = "null" ] || [ -z "$token" ]; then
        echo "Failed to extract token from response" >&2
        exit 1
    fi
    
    echo "$token"
}

# Create admin token
admin_token=$(create_admin_token "$GITEA_URL" "$ADMIN_USERNAME" "$ADMIN_PASSWORD")

# Output in Terraform external data source format
jq -n --arg token "$admin_token" '{token: $token}'