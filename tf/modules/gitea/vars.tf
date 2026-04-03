variable "gitea_address" {
  type        = string
  description = "Gitea server address"
}

variable "gitea_base_url" {
  type        = string
  description = "Override base URL for Gitea API (e.g., http://localhost:3000 during setup)"
  default     = ""
}

variable "gitea_admin_username" {
  type        = string
  description = "Gitea admin username"
  default     = "root"
}

variable "gitea_admin_password" {
  type        = string
  description = "Gitea admin password"
  sensitive   = true
}

variable "platform_cluster_name" {
  type        = string
  description = "Platform cluster name"
}

variable "gitea_platform_group" {
  type        = string
  description = "Gitea platform organization name"
}

variable "gitea_platform_robot_runtime_repo" {
  type        = string
  description = "Gitea platform robot runtime repository name"
}

variable "github_platform_robot_runtime_repo" {
  type        = string
  description = "GitHub platform robot runtime repository name"
}

variable "gitea_platform_rw_public_codecollection_repo" {
  type        = string
  description = "Gitea platform public code collection repository name"
}

variable "github_platform_rw_public_codecollection_repo" {
  type        = string
  description = "GitHub platform public code collection repository name"
}

variable "vault_ready" {
  type        = string
  description = "Dummy variable to enforce dependency on vault"
}