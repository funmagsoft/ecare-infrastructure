output "service_principal_app_id" {
  description = "Application (Client) ID of the Service Principal for GitHub Actions"
  value       = azuread_application.gha.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the Service Principal for GitHub Actions"
  value       = azuread_service_principal.gha.object_id
}

output "federated_identity_credentials" {
  description = "Map of repository names to their Federated Identity Credential IDs"
  value = {
    for repo, fic in azuread_application_federated_identity_credential.terraform_repos :
    repo => fic.id
  }
}
