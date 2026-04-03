# Gitea Configuration

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

## runwhen-machine user is pre-created by install_gitea.sh
## We use local values instead of gitea_user resource to avoid provider bugs
locals {
  runwhen_machine_username = "runwhen-machine"
  runwhen_machine_password = random_password.gitea_password.result
}

## Create platform organization
resource "gitea_org" "runwhen-platform" {
  name        = var.gitea_platform_group
  full_name   = "RunWhen Platform Organization"
  description = "RunWhen Platform Organization"
  visibility  = "private"
  website     = ""
  location    = ""
}

## Platform Robot Runtime Repository
resource "gitea_repository" "platform-robot-runtime" {
  username     = gitea_org.runwhen-platform.name
  name         = var.gitea_platform_robot_runtime_repo
  description  = "Robot Runtime - synced from GitHub"
  private      = true
  has_issues   = false
  has_wiki     = false
  has_pull_requests = true
  ignore_whitespace_conflicts = false
  allow_merge_commits = true
  allow_squash_merge = true
  allow_rebase = true
  default_branch = "main"
  gitignores = ""
  license = ""
  readme = "Default"
  auto_init = true
}

## Platform Public Code Collection Repository  
resource "gitea_repository" "platform-rw-public-codecollection" {
  username = gitea_org.runwhen-platform.name
  name         = var.gitea_platform_rw_public_codecollection_repo
  description  = "Public Code Collections - synced from GitHub"
  private      = true
  has_issues   = false
  has_wiki     = false
  has_pull_requests = true
  ignore_whitespace_conflicts = false
  allow_merge_commits = true
  allow_squash_merge = true
  allow_rebase = true
  default_branch = "main"
  gitignores = ""
  license = ""
  readme = "Default"
  auto_init = true
}

## Default Organization (bootstrap)
resource "gitea_org" "default-org" {
  name        = var.platform_cluster_name
  full_name   = "Default Organization"
  description = "Default Organization"
  visibility  = "private"
  website     = ""
  location    = ""
}

data "external" "add_runwhen_to_default_org_owners" {
  depends_on = [
    gitea_org.default-org,
    gitea_org.runwhen-platform
  ]
  program    = ["bash", "${path.module}/scripts/add_to_owners.sh"]
  query = {
    admin_username  = var.gitea_admin_username
    admin_password  = var.gitea_admin_password
    gitea_url       = var.gitea_base_url != "" ? var.gitea_base_url : "https://${var.gitea_address}"
    org_name        = gitea_org.default-org.name
    member_username = local.runwhen_machine_username
  }
}

data "external" "add_runwhen_to_runwhen_platform_owners" {
  depends_on = [
    gitea_org.runwhen-platform,
    gitea_org.runwhen-platform
  ]
  program    = ["bash", "${path.module}/scripts/add_to_owners.sh"]
  query = {
    admin_username  = var.gitea_admin_username
    admin_password  = var.gitea_admin_password
    gitea_url       = var.gitea_base_url != "" ? var.gitea_base_url : "https://${var.gitea_address}"
    org_name        = gitea_org.runwhen-platform.name
    member_username = local.runwhen_machine_username
  }
}
