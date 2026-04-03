# Gitea Config
module "gitea-config" {
  source = "../../modules/gitea"
  vault_ready = null_resource.vault_ready.id
  gitea_address = var.public_https_endpoints.gitea.host
  gitea_base_url = "http://localhost:3000"
  gitea_admin_username = "root"
  gitea_admin_password = var.gitea_admin_password
  platform_cluster_name = var.platform_cluster_name
  gitea_platform_group = "${var.gitea_platform_group}"
  gitea_platform_robot_runtime_repo = "platform-robot-runtime"
  github_platform_robot_runtime_repo = "platform-robot-runtime"
  gitea_platform_rw_public_codecollection_repo = "rw-public-codecollections"
  github_platform_rw_public_codecollection_repo = "platform-rw-public-codecollections"
}