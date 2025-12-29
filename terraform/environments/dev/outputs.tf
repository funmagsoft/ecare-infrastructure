# Re-export outputs from the identity module
output "github_oidc_service_principal_app_id" {
  description = "Application (Client) ID of the Service Principal for GitHub Actions (service repositories)"
  value       = module.environment.github_oidc_service_principal_app_id
}

output "github_oidc_service_principal_object_id" {
  description = "Object ID of the Service Principal for GitHub Actions (service repositories)"
  value       = module.environment.github_oidc_service_principal_object_id
}

output "github_oidc_federated_identity_credentials" {
  description = "Map of service names to their Federated Identity Credential IDs (GitHub OIDC for service repositories)"
  value       = module.environment.github_oidc_federated_identity_credentials
}

output "github_oidc_gitops_federated_identity_credentials" {
  description = "Map of GitOps repository names to their Federated Identity Credential IDs (GitHub OIDC for GitOps repositories per environment)"
  value       = module.environment.github_oidc_gitops_federated_identity_credentials
}

output "workload_identities" {
  description = "Map of workload identities per service"
  value       = module.environment.workload_identities
}


