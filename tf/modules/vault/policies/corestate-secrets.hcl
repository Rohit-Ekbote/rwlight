# Allow reading and listing secrets and versions but NOT modify the secret entirely, which is done through the metadata endpoint
path "corestate/data/*" {
  capabilities = ["read", "list"]
}
