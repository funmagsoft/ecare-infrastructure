# GitHub OIDC Integration Outputs
output "github_oidc_service_principal_app_id" {
  description = "Application (Client) ID of the Service Principal for GitHub Actions (service repositories)"
  value       = module.github_oidc_integration.service_principal_app_id
}

output "github_oidc_service_principal_object_id" {
  description = "Object ID of the Service Principal for GitHub Actions (service repositories)"
  value       = module.github_oidc_integration.service_principal_object_id
}

output "github_oidc_federated_identity_credentials" {
  description = "Map of service names to their Federated Identity Credential IDs (GitHub OIDC for service repositories)"
  value       = module.github_oidc_integration.federated_identity_credentials
}

output "github_oidc_gitops_federated_identity_credentials" {
  description = "Map of GitOps repository names to their Federated Identity Credential IDs (GitHub OIDC for GitOps repositories per environment)"
  value       = module.github_oidc_integration.gitops_federated_identity_credentials
}

# Workload Identity Outputs
output "workload_identities" {
  description = "Map of workload identities per service with complete identity information"
  value = {
    for name, mod in module.workload_identity :
    name => {
      identity_id               = mod.identity_id
      identity_name             = mod.managed_identity_name
      identity_client_id        = mod.identity_client_id
      identity_principal_id     = mod.identity_principal_id
      federated_credential_id   = mod.federated_credential_id
      federated_credential_name = mod.federated_credential_name
      service_account_name      = mod.service_account_name
      service_account_namespace = mod.service_account_namespace
      enabled_services          = mod.enabled_services
    }
  }
}
