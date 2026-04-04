## Template Policy to Assign to Runner AppRoles by corestate -- example
# Support reading secrets of a workspace using the old paths
path "workspaces/data/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/*" {
  capabilities = [ "read" ]
}

# Support listing of secrets of a workspace using the old paths
path "workspaces/metadata/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/*" {
  capabilities = [ "list" ]
}

# Support reading secrets of a workspace provided by a user within an org
path "org/data/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.org_name}}/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/user/*" {
  capabilities = [ "read" ]
}

# Support listing of secrets of a workspace provided by a user within an org
path "org/metadata/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.org_name}}/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/user/*" {
  capabilities = [ "list" ]
}

# Support reading of hook secrets of a workspace provided by a user or runwhen within an org
path "org/data/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.org_name}}/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/hook/*" {
  capabilities = [ "read" ]
}

# Support listing of hook secrets of a workspace provided by a user or runwhen within an org
path "org/metadata/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.org_name}}/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/hook/*" {
  capabilities = [ "list" ]
}

# Support reading of platform secrets of a workspace provided by runwhen within an org
path "org/data/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.org_name}}/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/platform/*" {
  capabilities = [ "read" ]
}

# Support listing of platform secrets of a workspace provided by runwhen within an org
path "org/metadata/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.org_name}}/workspace/{{identity.entity.aliases.${auth_mountpoint_alias}.metadata.workspace_name}}/platform/*" {
  capabilities = [ "list" ]
}