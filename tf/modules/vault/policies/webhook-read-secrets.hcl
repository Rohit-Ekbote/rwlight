# Support reading of webhook of secrets
path "org/metadata/+/workspace/+/system/webhooks/*" {
   capabilities = ["read","list"]
}

path "org/data/+/workspace/+/system/webhooks/*" {
   capabilities = ["read"]
}
