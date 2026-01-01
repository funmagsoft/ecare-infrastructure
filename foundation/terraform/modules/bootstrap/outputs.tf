output "service_principal_app_id" {
  description = "Application (Client) ID of the Service Principal for GitHub Actions"
  value       = azuread_application.gha.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the Service Principal for GitHub Actions"
  value       = azuread_service_principal.gha.object_id
}

output "service_principal_display_name" {
  description = "Display name of the Service Principal"
  value       = azuread_application.gha.display_name
}

output "application_id" {
  description = "Application (Object) ID of the Azure AD Application"
  value       = azuread_application.gha.id
}

output "federated_identity_credentials" {
  description = "Map of repository names (org/repo format) to their Federated Identity Credential IDs"
  value = {
    for repo, fic in azuread_application_federated_identity_credential.terraform_repos :
    repo => fic.id
  }
}

output "federated_identity_credentials_details" {
  description = "Detailed information about Federated Identity Credentials (repo, display_name, subject)"
  value = {
    for repo, fic in azuread_application_federated_identity_credential.terraform_repos :
    repo => {
      id           = fic.id
      display_name = fic.display_name
      subject      = fic.subject
      issuer       = fic.issuer
    }
  }
}

output "terraform_repos" {
  description = "List of Terraform repositories configured for this Service Principal"
  value       = local.terraform_repos_full
}
