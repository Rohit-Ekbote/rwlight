resource "vault_policy" "vault-users" {
  name = "vault-users"

  policy = file("${path.module}/policies/vault-users.hcl")
}

resource "vault_policy" "shared-secrets" {
  name = "shared-secrets"

  policy = file("${path.module}/policies/shared-secrets.hcl")
}

resource "vault_policy" "corestate-manage-workspaces" {
  name   = "corestate-manage-workspaces"
  policy = file("${path.module}/policies/corestate-manage-workspaces.hcl")
}

resource "vault_policy" "corestate-secrets" {
  name = "corestate-secrets"

  policy = file("${path.module}/policies/corestate-secrets.hcl")
}

resource "vault_policy" "papi-write-workspaces" {
  name = "papi-write-workspaces"

  policy = file("${path.module}/policies/papi-write-workspaces.hcl")
}

resource "vault_policy" "webhook-read-secrets" {
  name = "webhook-read-secrets"

  policy = file("${path.module}/policies/webhook-read-secrets.hcl")
}


resource "vault_policy" "slackbot-workspace-secrets" {
  name = "slackbot-workspace-secrets"

  policy = file("${path.module}/policies/slackbot-workspace-secrets.hcl")
}

resource "vault_policy" "runner-workspace-secrets" {
  name = "runner-workspace-secrets"

  policy = file("${path.module}/policies/runner-workspace-secrets.hcl")
}

resource "vault_policy" "celery-secrets" {
  name = "celery-secrets"

  policy = file("${path.module}/policies/celery-secrets.hcl")
}

resource "vault_policy" "sobrain-secrets" {
  name = "sobrain-secrets"

  policy = file("${path.module}/policies/sobrain-secrets.hcl")
}

resource "vault_policy" "agentfarm-secrets" {
  name = "agentfarm-secrets"

  policy = file("${path.module}/policies/agentfarm-secrets.hcl")
}

# Location policy template for workspaces
# don't need location policy on local
# resource "vault_policy" "location-policies" {
#   for_each = var.location_clusters
#   name = "location-policies-${each.value.name}"
#   policy = templatefile("${path.module}/policy_templates/location-policies.tpl", 
#   {
#       auth_mountpoint_alias = data.vault_auth_backend.kubernetes-location[each.value.name].accessor
#   }
#   )
# }

## Runner Policies
resource "vault_policy" "runner-system" {
  name = "runner-system"
  policy = file("${path.module}/policies/runner-system.hcl")

}

resource "vault_policy" "runner-policy" {
  name = "runner-policy"
  policy = templatefile("${path.module}/policy_templates/runner-policy.tpl", 
  {
      auth_mountpoint_alias = vault_auth_backend.runner.accessor
  }
  )
}