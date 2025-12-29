output "service_principal_app_id" {
  description = "Application (Client) ID of the Service Principal for GitHub Actions"
  value       = azuread_application.gha.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the Service Principal for GitHub Actions"
  value       = azuread_service_principal.gha.object_id
}

output "federated_identity_credentials" {
  description = "Map of service names to their Federated Identity Credential IDs (for service repositories)"
  value = {
    for service, fic in azuread_application_federated_identity_credential.service_repos :
    service => fic.id
  }
}

output "gitops_federated_identity_credentials" {
  description = "Map of GitOps repository names to their Federated Identity Credential IDs (for GitOps repositories per environment)"
  value = {
    for repo, fic in azuread_application_federated_identity_credential.gitops_repos :
    repo => fic.id
  }
}

