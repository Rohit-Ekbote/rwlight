# Manage Roles for locations
# This is more open than I'd like it to be. 
# We might consider templating out this policy in TF 
# and adding specific policy for each k8s location auth endpoint
path "/auth/+/role/*" {
   capabilities = ["create", "read", "delete", "list", "update"]
}

# Read available policies
path "/sys/policies/acl/*" {
   capabilities = ["read","list"]
}


## Allow listing of Auth endpoints
path "/sys/auth*" {
   capabilities = ["read"]
}


## Allow listing  and deleteing workspaces secret paths
path "workspaces/metadata/*" {
   capabilities = ["list", "delete"]
}

## Allow listing and deleting org secret paths such as deleting a workspace
path "org/metadata/+/workspace/*" {
   capabilities = ["list", "delete"]
}

## Allow Corestate to Manage Runner AppRole KV2 Secrets
path "org/metadata/+/workspace/+/system/runner/*" {
   capabilities = ["read", "delete", "list"]
}

path "org/data/+/workspace/+/system/runner/*" {
   capabilities = ["create", "read", "update"]
}

## Allow Corestate to Manage its workspace secrets
path "org/metadata/+/workspace/+/system/corestate/*" {
   capabilities = ["read", "delete", "list"]
}

path "org/data/+/workspace/+/system/corestate/*" {
   capabilities = ["create", "read", "update"]
}

## Allow Corestate to Manage Workspace Webhooks KV2 Secrets
path "org/metadata/+/workspace/+/system/webhooks/*" {
   capabilities = ["read", "delete", "list"]
}

path "org/data/+/workspace/+/system/webhooks/*" {
   capabilities = ["create", "read", "update"]
}
