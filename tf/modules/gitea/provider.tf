terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "github" {
  owner = "runwhen"
}
