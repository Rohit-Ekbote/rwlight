## Cluster
module "vault-config" {
  source = "../../modules/vault"
  vault_address  = "https://${var.public_https_endpoints.vault.host}"
  platform_cluster_name  = var.platform_cluster_name
  github_owner       = "runwhen"
  vault_github_team  =  "nonprod-vault-users"
  runwhen_machine_username = "runwhen-machine"
  runwhen_machine_token = module.gitea-config.runwhen-machine-token
  runwhen_machine_user_id = module.gitea-config.runwhen-machine-user-id
  runwhen_machine_user_password = "${module.gitea-config.runwhen-machine-user-password}"
  # Gitea credentials (conditional)
  # gitea_runwhen_machine_username = try(module.gitea-config.runwhen-machine-username, "")
  # gitea_runwhen_machine_token = try(module.gitea-config.runwhen-machine-token, "")
  # gitea_runwhen_machine_user_id = try(module.gitea-config.runwhen-machine-user-id, "")
  # gitea_runwhen_machine_user_password = try(module.gitea-config.runwhen-machine-user-password, "")
}

resource "null_resource" "vault_ready" {
  depends_on = [module.vault-config]
}
