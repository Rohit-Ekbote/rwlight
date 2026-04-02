## This needs to be removed at some point
# Allow reading and listing secrets and versions but NOT modify the secret entirely, which is done through the metadata endpoint
path "shared/data/*" {
  capabilities = ["read", "list"]
}


# ==============================Tokens=====================================

path "auth/token/create" {
  capabilities = ["create", "update"]
}
# Policy Read
path "sys/policy/shared-secrets" {
  capabilities = ["read", "list"]
}

path "sys/policies/acl/shared-secrets" {
  capabilities = ["read", "list"]
}
