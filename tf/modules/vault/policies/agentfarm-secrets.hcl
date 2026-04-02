# LLM Secret Access (pull keys for analysis with workspace defined LLM)
path "org/data/+/workspace/+/system/llm/*" {
  capabilities = ["read"]
}

# Support listing of secrets of a workspace
path "org/metadata/+/workspace/+/system/llm/*" {
  capabilities = [ "list" ]
}

path "org/data/+/system/llm/*" {
  capabilities = ["read"]
}

# Support listing of llm defaults 
path "org/metadata/+/system/llm/*" {
  capabilities = [ "list" ]
}
