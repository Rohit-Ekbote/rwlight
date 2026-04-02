# Per workspace policy template. Use vault auth list to obtain the accessor name
path "workspaces/data/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.service_account_namespace}}/*" {
  capabilities = [ "read" ]
}

# Support listing of secrets of a workspace
path "workspaces/metadata/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.service_account_namespace}}/*" {
  capabilities = [ "list" ]
}

path "org/data/+/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.service_account_namespace}}/*" {
  capabilities = [ "read" ]
}

# Support listing of secrets of a workspace
path "org/metadata/+/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.service_account_namespace}}/*" {
  capabilities = [ "list" ]
}