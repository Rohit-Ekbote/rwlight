variable "vault_address" {
  type     = string
}

variable "github_owner" {
  type     = string
}

variable  "vault_github_team" {
  type     = string
}

variable  "platform_cluster_name" {
  type     = string
}

variable "runwhen_machine_username" {
  type = string
}

variable "runwhen_machine_token" {
  type = string
}

variable "runwhen_machine_user_id" {
  type = string
}

variable "runwhen_machine_user_password" {
  type = string
}

# Gitea specific variables
variable "gitea_runwhen_machine_username" {
  type = string
  default = ""
}

variable "gitea_runwhen_machine_token" {
  type = string
  default = ""
}

variable "gitea_runwhen_machine_user_id" {
  type = string
  default = ""
}

variable "gitea_runwhen_machine_user_password" {
  type = string
  default = ""
}