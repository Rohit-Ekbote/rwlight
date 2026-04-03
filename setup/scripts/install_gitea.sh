#!/usr/bin/env bash
set -euo pipefail

### CONFIGURATION ###
NAMESPACE="gitea"
GITEA_RELEASE="gitea"
GITEA_DOMAIN="gitea.${SUBDOMAIN}.${DOMAIN}"
GITEA_ADMIN_EMAIL="admin@${SUBDOMAIN}.${DOMAIN}"
ORG_NAME="platform-setup"

# repo details
REPO_NAME="runwhen-platform-self-hosted-local-dev"
TF_REPO_NAME="infra"
BRANCH_NAME="main"

# Versions
GITEA_CHART_VERSION="10.6.0"
POSTGRES_VERSION="12.1.9"

### 1. Create namespace ###
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

### 2. Install Postgres ###
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update bitnami
helm upgrade --install postgres bitnami/postgresql \
  --namespace $NAMESPACE \
  --version $POSTGRES_VERSION \
  --set auth.username=gitea \
  --set auth.password=gitea_pass \
  --set auth.database=gitea \
  --set image.repository=bitnamilegacy/postgresql

### 3. Install Gitea ###
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update
helm upgrade --install $GITEA_RELEASE gitea-charts/gitea \
  --namespace $NAMESPACE \
  --version $GITEA_CHART_VERSION \
  --set gitea.admin.username=$GITEA_ADMIN_USER \
  --set gitea.admin.password=$GITEA_ADMIN_PASS \
  --set gitea.admin.email=$GITEA_ADMIN_EMAIL \
  --set gitea.config.server.DOMAIN=$GITEA_DOMAIN \
  --set gitea.config.server.ROOT_URL="https://$GITEA_DOMAIN/" \
  --set gitea.config.server.MAX_REQUEST_BODY_SIZE=209715200 \
  --set gitea.config.database.DB_TYPE=postgres \
  --set gitea.config.database.HOST=postgres-postgresql.$NAMESPACE.svc.cluster.local:5432 \
  --set gitea.config.database.NAME=gitea \
  --set gitea.config.database.USER=gitea \
  --set gitea.config.database.PASSWD=gitea_pass \
  --set service.http.type=ClusterIP \
  --set ingress.enabled=true \
  --set ingress.className=ingress-nginx \
  --set ingress.hosts[0].host=$GITEA_DOMAIN \
  --set ingress.hosts[0].paths[0].path="/" \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set ingress.tls[0].secretName=gitea-tls \
  --set ingress.tls[0].hosts[0]=$GITEA_DOMAIN \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-staging \
  --set ingress.annotations."nginx.ingress.kubernetes.io/proxy-body-size"="200m" \
  --set postgresql-ha.enabled=false \
  --set postgresql.enabled=false \
  --set redis-cluster.enabled=false \
  --set gitea.config.cache.ADAPTER=memory \
  --set gitea.config.session.PROVIDER=memory \
  --set gitea.config.queue.TYPE=level

### 4. Wait for Gitea to be ready ###
echo "⏳ Waiting for Gitea deployment to be ready..."
kubectl rollout status deployment/${GITEA_RELEASE} -n $NAMESPACE --timeout=300s

### 5. Port forward to Gitea (run in background) ###
echo "🔄 Setting up port forward to Gitea..."
kubectl port-forward -n "$NAMESPACE" svc/gitea-http 3000:3000 > /tmp/portforward.log 2>&1 &
PORT_FORWARD_PID=$!

# Function to clean up port-forward
cleanup_port_forward() {
    kill $PORT_FORWARD_PID 2>/dev/null
}
trap cleanup_port_forward EXIT

# Wait until the port-forward is ready (retry for up to 30s)
echo "🔄 Waiting for Gitea port-forward to become ready..."
for i in {1..30}; do
    if curl -s http://localhost:3000/api/healthz > /dev/null; then
        echo "✅ Gitea is accessible!"
        break
    fi
    sleep 1
done

# If loop completed without success
if ! curl -s http://localhost:3000/api/healthz > /dev/null; then
    echo "❌ Gitea is not accessible via port forward (timeout after 30s)"
    exit 1
fi

echo "✅ Gitea is accessible"

### 6. Get Gitea pod name ###
echo "🔄 Getting Gitea pod name..."
POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=gitea -o jsonpath="{.items[0].metadata.name}")
echo "📋 Using pod: $POD"

### 7. Get/Create admin API token ###
TOKEN=$(kubectl get secret gitea-bootstrap-token --namespace=gitea -o jsonpath='{.data.token}' | base64 -d || true)
if [ -z "$TOKEN" ] || [ "$TOKEN" == "None" ]; then
  echo "🔄 Generating admin API token..."
  TOKEN=$(kubectl exec -n $NAMESPACE $POD -- \
    gitea admin user generate-access-token \
      --username $GITEA_ADMIN_USER \
      --token-name bootstrap-token \
      --scopes all \
      --raw)

  if [ -z "$TOKEN" ]; then
      echo "❌ Failed to generate token"
      exit 1
  fi
fi

echo "✅ Gitea admin token generated: $TOKEN"

### 7b. Create runwhen-machine user ###
echo "🔄 Creating 'runwhen-machine' service user..."
RW_USER_RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/v1/admin/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d '{
    "username": "runwhen-machine",
    "email": "runwhen-machine@runwhen.com",
    "password": "RunWhen-Machine-Pass-2026!",
    "login_name": "runwhen-machine",
    "must_change_password": false,
    "visibility": "private"
  }')

RW_USER_HTTP_CODE="${RW_USER_RESPONSE: -3}"
if [ "$RW_USER_HTTP_CODE" = "201" ] || [ "$RW_USER_HTTP_CODE" = "422" ]; then
    echo "✅ User 'runwhen-machine' created (or already exists)"
else
    echo "⚠️  User creation returned HTTP $RW_USER_HTTP_CODE (may already exist)"
fi

### 8. Create organization ###
echo "🔄 Creating organization '$ORG_NAME'..."
ORG_RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/v1/orgs" \
  -H "Content-Type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d "{\"username\":\"$ORG_NAME\",\"visibility\":\"public\"}")

ORG_HTTP_CODE="${ORG_RESPONSE: -3}"
if [ "$ORG_HTTP_CODE" = "201" ] || [ "$ORG_HTTP_CODE" = "422" ]; then
    echo "✅ Organization '$ORG_NAME' created (or already exists)"
else
    echo "❌ Failed to create organization. HTTP Code: $ORG_HTTP_CODE"
    echo "Response: ${ORG_RESPONSE%???}"
fi

### 8b. Create runwhen-platform organization ###
PLATFORM_ORG="runwhen-platform"
echo "🔄 Creating organization '$PLATFORM_ORG'..."
curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/v1/orgs" \
  -H "Content-Type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d "{\"username\":\"$PLATFORM_ORG\",\"visibility\":\"private\"}" > /dev/null
echo "✅ Organization '$PLATFORM_ORG' created (or already exists)"

### 8c. Create default org (cluster name) ###
echo "🔄 Creating organization '${CLUSTER}'..."
curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/v1/orgs" \
  -H "Content-Type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d "{\"username\":\"${CLUSTER}\",\"visibility\":\"private\"}" > /dev/null
echo "✅ Organization '${CLUSTER}' created (or already exists)"

### 8d. Create platform repos ###
for REPO in platform-robot-runtime rw-public-codecollections; do
  echo "🔄 Creating repository '$PLATFORM_ORG/$REPO'..."
  curl -s -X POST "http://localhost:3000/api/v1/orgs/$PLATFORM_ORG/repos" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $TOKEN" \
    -d "{\"name\":\"$REPO\",\"private\":true,\"auto_init\":true,\"default_branch\":\"main\"}" > /dev/null
  echo "✅ Repository '$REPO' created (or already exists)"
done

### 8e. Add runwhen-machine to org owners ###
for ORG in "$PLATFORM_ORG" "${CLUSTER}"; do
  echo "🔄 Adding runwhen-machine to '$ORG' owners..."
  # Get owners team ID
  TEAMS=$(curl -s "http://localhost:3000/api/v1/orgs/$ORG/teams" \
    -H "Authorization: token $TOKEN")
  OWNERS_TEAM_ID=$(echo "$TEAMS" | jq -r '.[] | select(.name=="Owners") | .id')
  if [ -n "$OWNERS_TEAM_ID" ] && [ "$OWNERS_TEAM_ID" != "null" ]; then
    curl -s -X PUT "http://localhost:3000/api/v1/teams/$OWNERS_TEAM_ID/members/runwhen-machine" \
      -H "Authorization: token $TOKEN" > /dev/null
    echo "✅ runwhen-machine added to '$ORG' owners"
  else
    echo "⚠️  Could not find Owners team for '$ORG'"
  fi
done

### 9. Create repo in Gitea and push from local INFRA_DIR ###
echo "🔄 Creating repository '$REPO_NAME' in organization '$ORG_NAME'..."
CREATE_REPO_RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/v1/orgs/$ORG_NAME/repos" \
  -H "Content-Type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d "{\"name\":\"$REPO_NAME\",\"private\":false,\"auto_init\":false}")

CREATE_REPO_HTTP_CODE="${CREATE_REPO_RESPONSE: -3}"
if [ "$CREATE_REPO_HTTP_CODE" = "201" ]; then
    echo "✅ Repository '$REPO_NAME' created"
elif [ "$CREATE_REPO_HTTP_CODE" = "409" ]; then
    echo "✅ Repository '$REPO_NAME' already exists"
else
    echo "❌ Failed to create repository. HTTP Code: $CREATE_REPO_HTTP_CODE"
    echo "Response: ${CREATE_REPO_RESPONSE%???}"
    exit 1
fi

echo "🔄 Pushing code from '$INFRA_DIR' to '$ORG_NAME/$REPO_NAME'..."
GIT_REPO_URL_WITH_CREDS="http://$GITEA_ADMIN_USER:$TOKEN@localhost:3000/$ORG_NAME/$REPO_NAME.git"

# Copy to a temp directory to avoid git-in-git issues when source is inside a worktree
INFRA_TMP=$(mktemp -d)
rsync -a --exclude='.git' "$INFRA_DIR/" "$INFRA_TMP/"

(cd "$INFRA_TMP" && \
  git init -q --initial-branch="$BRANCH_NAME" && \
  git config user.name "runwhen-machine" && \
  git config user.email "runwhen-machine@runwhen.com" && \
  git add . && \
  git commit -m "Initial Commit" && \
  git remote add gitea "$GIT_REPO_URL_WITH_CREDS" && \
  git push --set-upstream gitea "$BRANCH_NAME" -f)

rm -rf "$INFRA_TMP"
echo "✅ Code pushed to http://localhost:3000/$ORG_NAME/$REPO_NAME"

### 10. Create repo in Gitea and push from local TF_DIR ###
echo "🔄 Creating repository '$TF_REPO_NAME' in organization '$ORG_NAME'..."
CREATE_REPO_RESPONSE=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/v1/orgs/$ORG_NAME/repos" \
  -H "Content-Type: application/json" \
  -H "Authorization: token $TOKEN" \
  -d "{\"name\":\"$TF_REPO_NAME\",\"private\":false,\"auto_init\":false}")

CREATE_REPO_HTTP_CODE="${CREATE_REPO_RESPONSE: -3}"
if [ "$CREATE_REPO_HTTP_CODE" = "201" ]; then
    echo "✅ Repository '$TF_REPO_NAME' created"
elif [ "$CREATE_REPO_HTTP_CODE" = "409" ]; then
    echo "✅ Repository '$TF_REPO_NAME' already exists"
else
    echo "❌ Failed to create repository. HTTP Code: $CREATE_REPO_HTTP_CODE"
    echo "Response: ${CREATE_REPO_RESPONSE%???}"
    exit 1
fi

echo "🔄 Pushing code from '$TF_DIR' to '$ORG_NAME/$TF_REPO_NAME'..."
GIT_REPO_URL_WITH_CREDS="http://$GITEA_ADMIN_USER:$TOKEN@localhost:3000/$ORG_NAME/$TF_REPO_NAME.git"

# Copy to a temp directory to avoid git-in-git issues when source is inside a worktree
TF_TMP=$(mktemp -d)
rsync -a --exclude='.git' "$TF_DIR/" "$TF_TMP/"

(cd "$TF_TMP" && \
  git init -q --initial-branch="$BRANCH_NAME" && \
  git config user.name "runwhen-machine" && \
  git config user.email "runwhen-machine@runwhen.com" && \
  git add . && \
  git commit -m "Initial Commit" && \
  git remote add gitea "$GIT_REPO_URL_WITH_CREDS" && \
  git push --set-upstream gitea "$BRANCH_NAME" -f)

rm -rf "$TF_TMP"
echo "✅ Code pushed to http://localhost:3000/$ORG_NAME/$TF_REPO_NAME"

# Clean up port forward
echo "🧹 Cleaning up port forward..."

echo "✅ Repository available in $ORG_NAME/$TF_REPO_NAME"

kubectl create secret generic gitea-bootstrap-token \
  --namespace $NAMESPACE \
  --from-literal=token="$TOKEN" \
  --from-literal=repo-url="http://gitea-http.$NAMESPACE.svc.cluster.local:3000/$ORG_NAME/$REPO_NAME" \
  --from-literal=git-url="http://gitea-http.$NAMESPACE.svc.cluster.local:3000/$ORG_NAME/$REPO_NAME.git" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Gitea setup complete. Token and URLs stored in secret."
