resource "vault_mount" "runwhen" {
  path = "runwhen"
  type = "kv"

  options = {
    version = 2
  }
}

resource "vault_mount" "shared" {
  path = "shared"
  type = "kv"

  options = {
    version = 2
  }
}


resource "vault_mount" "operations" {
  path = "operations"
  type = "kv"

  options = {
    version = 2
  }

  description = "Secrets for runwhen Operations"
}

// This was manually? added in test/tiger and imported. unsure of why/how they were created originally. 
resource "vault_mount" "runner-system" {
  path = "runner-system"
  type = "kv"

  options = {
    version = 2
  }

  description = "Runner Control Mount"
}

resource "vault_mount" "papi" {
  path = "papi"
  type = "kv"

  options = {
    version = 2
  }

  description = "Secrets for papi"
}


resource "vault_mount" "corestate" {
  path = "corestate"
  type = "kv"

  options = {
    version = 2
  }

  description = "Secrets for corestate"
}



## Location specific secrets for workspaces
## Workspaces need to be the same name as the kubernetes workspace
resource "vault_mount" "workspaces" {
  path = "workspaces"
  type = "kv"

  options = {
    version = 2
  }

  description = "Secrets for specific customer workspaces (to be migrated to /orgs)"
}

resource "vault_mount" "locations" {
  path = "locations"
  type = "kv"

  options = {
    version = 2
  }

  description = "Secrets for locations (unsure if this is needed/used)"
}


resource "vault_mount" "org" {
  path = "org"
  type = "kv"

  options = {
    version = 2
    max_versions = 1
  }

  description = "Main secret mount for customers, starting with Orgs as the root path"
}

