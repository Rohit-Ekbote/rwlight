# Allow writing and updating of secrets to the locations endpoint
path "workspaces/data/*" {
  capabilities = ["create", "update"]
}

# Support listing of secrets of a workspace
path "workspaces/metadata/*" {
  capabilities = [ "list" ]
}

## Allow listing of KV2 for the locations endpoint
path "locations/metadata/*" {
   capabilities = ["list"]
}

# New Org path 
path "org/data/+/workspace/*" {
  capabilities = ["create", "update"]
}

# Support listing of secrets
path "org/metadata/+/workspace/*" {
  capabilities = [ "list" ]
}

# Write system secrets
path "org/data/+/system/+/*" {
  capabilities = ["create", "update"]
}

# Write system secrets
path "org/metadata/+/system/+/*" {
  capabilities = ["list"]
}
