# List the user folders
path "runwhen/metadata/" {
  capabilities = ["list"]
}

# Show the root folder in the secrets hierarchy (needed so the folder appears in the UI)
path "runwhen/metadata/shared/*" {
  capabilities = ["read", "list"]
}

# Allow access to manage secrets and versions but NOT delete the secret entirely, which is done through the metadata endpoint
path "runwhen/data/shared/*" {
  capabilities = ["create", "read", "list", "update"]
}

# ==============================App Secrets =================================
# These are not for production use - read shared secrets for debugging
# List the shared folders
path "shared/metadata/*" {
  capabilities = ["read", "list"]
} 

# Allow access to manage secrets and versions but NOT delete the secret entirely, which is done through the metadata endpoint
path "shared/data/*" {
  capabilities = ["create", "read", "list", "update"]
}


# ==============================runwhen Users================================

# List the user folders
path "runwhen/metadata/users" {
  capabilities = ["list"]
}

# ==============================Tokens=====================================
path "auth/token/create" {
  capabilities = ["create", "update"]
}

# Policy Read
path "sys/policy/vault-users" {
  capabilities = ["read", "list"]
}

path "sys/policies/acl/vault-users" {
  capabilities = ["read", "list"]
}


# ==========================Debug=====================================
# Read available policies
path "/sys/policies/acl/*" {
   capabilities = ["read","list"]
}


## Allow listing of Auth endpoints
path "/sys/auth*" {
   capabilities = ["read","list"]
}