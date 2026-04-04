#!/usr/bin/env bash
set -euo pipefail

eval "$(jq -r '@sh "ADMIN_USERNAME=\(.admin_username) ADMIN_PASSWORD=\(.admin_password) GITEA_URL=\(.gitea_url) ORG_NAME=\(.org_name) MEMBER_USERNAME=\(.member_username)"')"

TEAM_ID=$(curl -s -k \
    -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    "${GITEA_URL}/api/v1/orgs/${ORG_NAME}/teams" \
    | jq '.[] | select(.name=="Owners") | .id')

if [[ -z "$TEAM_ID" ]]; then
  jq -n --arg message "Owners team not found in org: $ORG_NAME" '{"error":$message}'
  exit 1
fi

curl -s -k -X PUT \
  -H "Content-Type: application/json" \
  -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
  "${GITEA_URL}/api/v1/teams/${TEAM_ID}/members/${MEMBER_USERNAME}" > /dev/null

jq -n --arg message "Added ${MEMBER_USERNAME} to Owners team in ${ORG_NAME}" '{"message":$message}'
