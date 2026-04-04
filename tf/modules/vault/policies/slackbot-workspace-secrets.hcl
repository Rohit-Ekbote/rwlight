# Allow writing and updating of secrets to the workspace slackbot path
path "org/data/+/workspace/+/system/slackbot/*" {
  capabilities = ["create", "update", "read", "delete"]
}

# Support listing of secrets of a workspace
path "org/metadata/+/workspace/+/system/slackbot/*" {
  capabilities = [ "list" ]
}

path "org/data/+/system/slackbot/*" {
  capabilities = ["create", "update", "read", "delete"]
}

# Support listing of secrets of a workspace
path "org/metadata/+/system/slackbot/*" {
  capabilities = [ "list" ]
}
