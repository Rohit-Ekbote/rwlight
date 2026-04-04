output "runwhen-machine-token" {
  value     = data.external.get-gitea-admin-token.result.token
  sensitive = true
}

output "runwhen-machine-user-id" {
  value = 0  # User pre-created by install_gitea.sh, ID not needed
}

output "runwhen-machine-user-password" {
  value     = random_password.gitea_password.result
  sensitive = true
}

output "runwhen-machine-username" {
  value = local.runwhen_machine_username
}
