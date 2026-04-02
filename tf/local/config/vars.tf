variable "public_https_endpoints" {
  type = map
}

variable "platform_cluster_name" {
  type = string
}

variable "basename" {
  type = string
}

variable "gitea_platform_group" {
  type = string
  description = "Gitea platform organization name"
  default = "runwhen-platform"
}

variable "gitea_admin_password" {
  type = string
  description = "Gitea admin password"
  sensitive = true
}