locals {
  # This changes on every Terraform run (plan/apply).
  # Each plan sees a new timestamp, forcing a data source refresh.
  force_refresh_timestamp = timestamp()
}


resource "vault_github_auth_backend" "org" {
  organization = var.github_owner
  tune {
    default_lease_ttl = "4h"
    max_lease_ttl     = "8h"
    token_type        = "default-service"
  }
}



# Control Plane Cluster Details
# data "terraform_remote_state" "gke" {
#   backend = "local"
#   config = {
#     path        = "/workspace/terraform.tfstate"
#   }
# }

# resource "null_resource" "control-plane-fetch-creds" {
#     provisioner "local-exec" {
#     command = "kubectl get secret -n ${var.platform_cluster_name}"
#   }
# }

# Sample to fetch connection details secret
data "kubernetes_secret" "platform-connection" {
  metadata {
    name = "gke-conn"
    namespace = var.platform_cluster_name
  }
}

resource "vault_auth_backend" "kubernetes-platform" {
  type = "kubernetes"
  path = "kubernetes"
  tune {
    default_lease_ttl = "300s"
    max_lease_ttl     = "600s"
  }
  description = "Platform Cluster"
}



resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend                = vault_auth_backend.kubernetes-platform.path
  kubernetes_host        = "https://kubernetes.default"
  disable_iss_validation = true
}

resource "vault_kubernetes_auth_backend_role" "shared_secrets" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "shared_secrets"
  bound_service_account_names      = ["corestate-controller-manager", "papi-sa", "vault-csi-provider", "gitservice-sa", "default", "slackbot-sa", "litellm-proxy-sa", "celery-sa", "sobrain-sa", "agentfarm-sa"]
  bound_service_account_namespaces = ["backend-services", "corestate", "vault", "test", "flux-system", "monitoring", "cortex", "llm-gateway"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.shared-secrets.name]
}

resource "vault_kubernetes_auth_backend_role" "sobrain-secrets" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "sobrain-secrets"
  bound_service_account_names      = ["sobrain-sa",  "vault-csi-provider"]
  bound_service_account_namespaces = ["backend-services", "vault"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.sobrain-secrets.name]
}

resource "vault_kubernetes_auth_backend_role" "agentfarm-secrets" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "agentfarm-secrets"
  bound_service_account_names      = ["agentfarm-sa",  "vault-csi-provider"]
  bound_service_account_namespaces = ["backend-services", "vault"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.agentfarm-secrets.name]
}

# allow corestate to create secrets for locations and workspaces
resource "vault_kubernetes_auth_backend_role" "corestate-manage-workspaces" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "corestate-manage-workspaces"
  bound_service_account_names      = ["cs-devkit-sa", "corestate-controller-manager", "vault-csi-provider"]
  bound_service_account_namespaces = ["corestate"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.corestate-manage-workspaces.name, vault_policy.corestate-secrets.name]
}

# allow PAPI to create secrets for workspaces
resource "vault_kubernetes_auth_backend_role" "papi-write-workspaces" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "papi-write-workspaces"
  bound_service_account_names      = ["vault-csi-provider", "papi-sa"]
  bound_service_account_namespaces = ["backend-services"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.papi-write-workspaces.name]
}

# allow Slackbot to create secrets for workspaces
resource "vault_kubernetes_auth_backend_role" "slackbot-workspace-secrets" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "slackbot-workspace-secrets"
  bound_service_account_names      = ["slackbot-sa", "celery-sa"]
  bound_service_account_namespaces = ["backend-services"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.slackbot-workspace-secrets.name]
}

# webhook and papi to read secrets
resource "vault_kubernetes_auth_backend_role" "webhook-read-secrets" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "webhook-read-secrets"
  bound_service_account_names      = ["webhooks-sa", "webhook-sa", "papi-sa"]
  bound_service_account_namespaces = ["backend-services"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.webhook-read-secrets.name]
}

# celery read secrets
resource "vault_kubernetes_auth_backend_role" "celery-secrets" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "celery-secrets"
  bound_service_account_names      = ["celery-sa", "vault-csi-provider"]
  bound_service_account_namespaces = ["backend-services", "vault"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.celery-secrets.name]
}

# don't need location policy on local
# Fetch location secret
# data "kubernetes_secret" "location-connection" {
#   for_each = var.location_clusters
#   metadata {
#     name = "gke-conn"
#     namespace = each.value.name
#   }
# }

data "external" "get-vault-jwt-from-clusters" {
  program = ["bash", "${path.module}/scripts/jwt_extractor.sh"]
  query = {
    namespace = "vault"
    secret_name = "vault-sa-token"
  }
}

# don't need location policy on local
# resource "vault_auth_backend" "kubernetes-location" {
#   for_each = var.location_clusters
#   type = "kubernetes"
#   path = "kubernetes-${each.value.name}"
#   tune {
#     default_lease_ttl = "300s"
#     max_lease_ttl     = "600s"
#   }
#   description = "${each.value.name} Cluster"
# }

# Need to solve for the missing JWT ref
#resource "vault_kubernetes_auth_backend_config" "kubernetes-location" {
#  for_each = var.location_clusters
#  backend                = vault_auth_backend.kubernetes-location[each.value.name].path
#  kubernetes_host        = data.kubernetes_secret.location-connection[each.value.name].data.endpoint
#  kubernetes_ca_cert     = data.kubernetes_secret.location-connection[each.value.name].data.clusterCA
#  # token_reviewer_jwt     = file("../creds/${each.value.name}.jwt")
#  token_reviewer_jwt = data.external.get-vault-jwt-from-clusters[each.value.name].result.jwt
#  disable_iss_validation = true
#}

# don't need location policy on local
# resource "vault_kubernetes_auth_backend_config" "kubernetes-location" {
#   for_each = var.location_clusters

#   backend    = vault_auth_backend.kubernetes-location[each.value.name].path

#   # Parse the host + CA from the single 'kubeconfig' key in the secret:
#   kubernetes_host = yamldecode(
#       data.kubernetes_secret.location-connection[each.value.name].data.kubeconfig
#   )["clusters"][0]["cluster"]["server"]

#   kubernetes_ca_cert = yamldecode(
#       data.kubernetes_secret.location-connection[each.value.name].data.kubeconfig
#   )["clusters"][0]["cluster"]["certificate-authority-data"]

#   token_reviewer_jwt     = data.external.get-vault-jwt-from-clusters[each.value.name].result.jwt
#   disable_iss_validation = true
#   lifecycle {
#     ignore_changes = [token_reviewer_jwt, kubernetes_ca_cert]
#   }
# }

# don't need location policy on local
# resource "vault_kubernetes_auth_backend_role" "shared_secrets_locations" {
#   for_each = var.location_clusters
#   backend                          = vault_auth_backend.kubernetes-location[each.value.name].path
#   role_name                        = "shared_secrets"
#   bound_service_account_names      = ["location-sa", "default"]
#   bound_service_account_namespaces = ["vault", "location", "test", "linkerd-multicluster"]
#   token_ttl                        = 300
#   token_policies                   = [vault_policy.shared-secrets.name]
# }

# don't need location policy on local
# Determine accessor resource for location policies 
# data "vault_auth_backend" "kubernetes-location" {
#   for_each = var.location_clusters
#   path = vault_auth_backend.kubernetes-location[each.value.name].path
# }



## Runner Auth MountPoints & Roles
resource "vault_kubernetes_auth_backend_role" "runner-control" {
  backend                          = vault_auth_backend.kubernetes-platform.path
  role_name                        = "runner-control"
  bound_service_account_names      = ["runner-control"]
  bound_service_account_namespaces = ["runner-system"]
  token_ttl                        = 300
  token_policies                   = [vault_policy.runner-system.name]
}


resource "vault_auth_backend" "runner" {
  type = "approle"
  path = "runner"
  tune {
    default_lease_ttl = "300s"
    max_lease_ttl     = "600s"
  }
  description = "Runner AppRole Auth"
}

resource "vault_approle_auth_backend_role" "runner" {
  backend         = vault_auth_backend.runner.path
  role_name       = "runner-role"
  token_policies  = [vault_policy.runner-policy.name]
}