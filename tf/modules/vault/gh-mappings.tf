resource "vault_github_team" "vault-users" {
  backend  = vault_github_auth_backend.org.id
  team     = var.vault_github_team
  policies = ["vault-users"]
}


# resource "null_resource" "vault-users" {
#   provisioner "local-exec" {
#     command = "export VAULT_ADDR=${var.vault_address} && vault write auth/github/map/teams/vault-users value=vault-users"
#   }
# }