terraform {
  required_providers {
    gitea = {
      source  = "Lerentis/gitea"
      version = "~> 0.16.0"
    }
  }
}

provider "gitea" {
  base_url = var.gitea_base_url != "" ? var.gitea_base_url : "https://${var.gitea_address}"
  username = var.gitea_admin_username
  password = var.gitea_admin_password
  insecure = true
}

provider "github" {
  owner = "runwhen"
}