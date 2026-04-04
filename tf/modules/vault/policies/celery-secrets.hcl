# Allow reading secrets to the workspace slackbot path
path "org/data/+/workspace/+/system/slackbot/*" {
  capabilities = ["read"]
}

# Support listing of secrets of a workspace
path "org/metadata/+/workspace/+/system/slackbot/*" {
  capabilities = [ "list" ]
}

path "org/data/+/system/slackbot/*" {
  capabilities = ["read"]
}

# Support listing of secrets of a workspace
path "org/metadata/+/system/slackbot/*" {
  capabilities = [ "list" ]
}

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
