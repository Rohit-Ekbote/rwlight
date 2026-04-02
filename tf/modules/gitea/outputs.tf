output "runwhen-machine-token" {
  value     = data.external.get-gitea-admin-token.result.token
  sensitive = true
}

output "runwhen-machine-user-id" {
  value = gitea_user.runwhen-machine.id
}

output "runwhen-machine-user-password" {
  value     = random_password.gitea_password.result
  sensitive = true
}

output "runwhen-machine-username" {
  value = gitea_user.runwhen-machine.username
}