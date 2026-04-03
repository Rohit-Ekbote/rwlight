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
  token    = data.external.get-gitea-admin-token.result.token
  insecure = true
}

provider "github" {
  owner = "runwhen"
}