# output "kubectl_complete" {
#     value = data.external.get-runwhen-sa-jwt-from-clusters.result.jwt
#     sensitive = true
#     # depends_on = [data.external.get-runwhen-sa-jwt-from-clusters]
# }