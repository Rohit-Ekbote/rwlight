data "external" "get-runwhen-sa-jwt-from-clusters" {
  depends_on = [data.external.get-vault-jwt-from-clusters]
  program = ["bash", "${path.module}/scripts/jwt_extractor.sh"]
  query = {
    namespace = "admin"
    secret_name = "runwhen-admin-token"
  }
}

# Create platform kubeconfig for locations
#resource "vault_kv_secret_v2" "platform-kubeconfig" {
#  mount                      = vault_mount.shared.path
#  name                       = "platform-kubeconfig"
#  cas                        = 1
#  delete_all_versions        = false
#  data_json                  = jsonencode(
#  {
#    kubeconfig       =  templatefile("${path.module}/config_templates/platform_kubeconfig.tpl", 
#        {
#            certificate-authority-data = base64encode(data.kubernetes_secret.platform-connection.data.clusterCA)
#            server_address = data.kubernetes_secret.platform-connection.data.endpoint
#            cluster_name = var.platform_cluster_name
#            user_name = "runwhen-admin"
#            context_name = var.platform_cluster_name
#            token = data.external.get-runwhen-sa-jwt-from-clusters.result.jwt
#        }    
#    )
#  }
#  )
#}

# ToDo: verify if we can populate this on local
# resource "vault_kv_secret_v2" "platform-kubeconfig" {
#   mount               = vault_mount.shared.path
#   name                = "platform-kubeconfig"
#   cas                 = 1
#   delete_all_versions = false

#   data_json = jsonencode({
#     kubeconfig = templatefile("${path.module}/config_templates/platform_kubeconfig.tpl",
#       {
#         certificate-authority-data = yamldecode(
#           data.kubernetes_secret.platform-connection.data.kubeconfig
#         )["clusters"][0]["cluster"]["certificate-authority-data"]

#         server_address = yamldecode(
#           data.kubernetes_secret.platform-connection.data.kubeconfig
#         )["clusters"][0]["cluster"]["server"]

#         cluster_name = var.platform_cluster_name
#         user_name    = "runwhen-admin"
#         context_name = var.platform_cluster_name

#         token = data.external.get-runwhen-sa-jwt-from-clusters.result.jwt
#       }
#     )
#   })
# }
# Create secret path for git service creds
resource "vault_kv_secret_v2" "git-service" {
  mount                      = vault_mount.shared.path
  name                       = "git-service"
  cas                        = 1
  delete_all_versions        = false
  data_json                  = jsonencode(
  {
    username = var.runwhen_machine_username
    token = var.runwhen_machine_token
    user_id = var.runwhen_machine_user_id
    password = var.runwhen_machine_user_password
  }
  )
}

# Create secret path for gitea service creds
resource "vault_kv_secret_v2" "gitea-service" {
  count                      = var.gitea_runwhen_machine_username != "" ? 1 : 0
  mount                      = vault_mount.shared.path
  name                       = "gitea-service"
  cas                        = 1
  delete_all_versions        = false
  data_json                  = jsonencode(
  {
    username = var.gitea_runwhen_machine_username
    token = var.gitea_runwhen_machine_token
    user_id = var.gitea_runwhen_machine_user_id
    password = var.gitea_runwhen_machine_user_password
  }
  )
}


# Some reference to legacy usage?
resource "vault_kv_secret_v2" "runner-control-encryption-key" {
  mount = "runner-system"
  name  = "runner-control"

  data_json = jsonencode({
    RUNNER_ENCRYPTION_KEY = "12345678901234567890123456789012"
  })

  depends_on = [vault_mount.runner-system]
}

resource "vault_kv_secret_v2" "secrets" {
  mount = "shared"
  name  = "secrets"

  data_json = jsonencode({
    "secrets.py" = <<EOT
"""
generate using: python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
in any env where django is installed. assign the output to the DJANGO_DB_SECRET_KEY key
"""
DJANGO_DB_SECRET_KEY='hHVGsWxNty0uIyTtIn9ep1eJt1aDITn5of4ecQLeaGs6d/E1z9DNrIMApuJMLJ0tQi0='

SOCIAL_ACCOUNT_PROVIDERS_GOOGLE_APP_CLIENT_ID=''
SOCIAL_ACCOUNT_PROVIDERS_GOOGLE_APP_CLIENT_SECRET=''

SOCIAL_ACCOUNT_PROVIDERS_GITHUB_APP_CLIENT_ID=''
SOCIAL_ACCOUNT_PROVIDERS_GITHUB_APP_CLIENT_SECRET=''
ACCOUNT_DEFAULT_HTTP_PROTOCOL='https'

import os
os.environ["AUTH0_URL"] = "https://auth.test.runwhen.com"
os.environ["SOCIAL_ACCOUNT_PROVIDERS_AUTH0_APP_CLIENT_ID"] = ""
os.environ["SOCIAL_ACCOUNT_PROVIDERS_AUTH0_APP_CLIENT_SECRET"] = ""

GITSERVICE_PLATFORM_USERNAME='runwhen-machine'
GITSERVICE_PLATFORM_PERSONAL_ACCESS_TOKEN='${var.gitea_runwhen_machine_token}' # get from shared/gitea-service

RUNWHEN_SLACK_RUNBOT_TOKEN=""

ACTIVITY_PROCESSOR_EMAIL_MAILGUN_API_KEY=""

GWORKSPACE_SYSTEM_USER_CREDS_JSONS=""

PINECONE_ACCOUNT_API_KEY = ""
OPENAI_ACCOUNT_API_KEY = "" # contact abid
EOT
  })

  depends_on = [vault_mount.shared]
}

resource "vault_kv_secret_v2" "gitlab_oauth" {
  mount = "shared"
  name  = "gitlab_oauth"

  data_json = jsonencode({
    SOCIAL_ACCOUNT_PROVIDERS_GITLAB_APP_CLIENT_ID = "abc"
    SOCIAL_ACCOUNT_PROVIDERS_GITLAB_APP_CLIENT_SECRET = "abc"
  })

  depends_on = [ vault_mount.shared ]
}

resource "vault_kv_secret_v2" "slackbot" {
  mount = "shared"
  name = "slackbot"

  data_json = jsonencode({
    FERNET_KEY = ""
    SLACK_CLIENT_ID = ""
    SLACK_CLIENT_SECRET = ""
    SLACK_SIGNING_SECRET = ""
  })

  depends_on = [ vault_mount.shared ]
}

resource "vault_kv_secret_v2" "platform-kubeconfig" {
  mount = "shared"
  name = "platform-kubeconfig"

  data_json = jsonencode({
    kubeconfig = ""
  })

  depends_on = [ vault_mount.shared ]
}

resource "random_password" "master_key" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  lifecycle {
    ignore_changes = all
  }
}

resource "random_password" "salt_key" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  lifecycle {
    ignore_changes = all
  }
}

# litellm install creds
resource "vault_kv_secret_v2" "litellm-creds" {
  mount                      = vault_mount.shared.path
  name                       = "litellm-proxy/creds"
  cas                        = 1
  delete_all_versions        = false
  lifecycle {
    ignore_changes = [data_json]
  }
  data_json                  = jsonencode(
  {
    litellm-master-key = random_password.master_key.result
    litellm-salt-key = random_password.salt_key.result
    slack-webhook-url = "https://hooks.slack.com/services/REPLACE/WITH/YOUR_WEBHOOK_URL"
  }
  )
 }

resource "vault_kv_secret_v2" "litellm-keys" {
  mount                      = vault_mount.shared.path
  name                       = "litellm-proxy/virtual-keys"
  cas                        = 1
  delete_all_versions        = false
  lifecycle {
    ignore_changes = [data_json]
  }
  data_json                  = jsonencode(
  {
    rw_shared_llm_vkey = "123456789"
    RW_SHARED_LLM = "abcdef"
  }
  )
}
