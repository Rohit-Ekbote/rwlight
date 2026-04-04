terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# data "google_client_config" "current" {}


provider "vault" {
  address = "${var.vault_address}"
  skip_tls_verify = true
}


provider "kubernetes" {
  # Use KUBECONFIG env var — works in both Docker container and Lima VM
}