# Gitea Configuration
# All Gitea resources (user, orgs, repos) are created by install_gitea.sh via API
# This module only provides the admin token and random passwords for Vault

## Generate admin token for API access
data "external" "get-gitea-admin-token" {
  program = ["bash", "${path.module}/scripts/gitea_admin_token.sh"]
  query = {
    admin_username   = var.gitea_admin_username
    admin_password   = var.gitea_admin_password
    gitea_url        = var.gitea_base_url != "" ? var.gitea_base_url : "https://${var.gitea_address}"
  }
}

## Create random password for the runwhen-machine user
resource "random_password" "gitea_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  lifecycle {
    ignore_changes = all
  }
}

locals {
  runwhen_machine_username = "runwhen-machine"
}
