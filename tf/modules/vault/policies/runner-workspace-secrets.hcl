# Allow writing and updating of secrets to the workspace runner path
path "org/data/+/workspace/+/system/runner/*" {
  capabilities = ["create", "update", "read"]
}

# Support listing of secrets of a workspace
path "org/metadata/+/workspace/+/system/runner/*" {
  capabilities = [ "list" ]
}
