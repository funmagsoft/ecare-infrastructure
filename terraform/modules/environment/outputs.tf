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
  description = "Map of service names to their Federated Identity Credential IDs (GitHub OIDC)"
  value       = module.github_oidc_integration.federated_identity_credentials
}

# Workload Identity Outputs
output "workload_identities" {
  description = "Map of workload identities per service"
  value = {
    for name, mod in module.workload_identity :
    name => {
      identity_id           = mod.identity_id
      identity_client_id    = mod.identity_client_id
      identity_principal_id = mod.identity_principal_id
      federated_credential  = mod.federated_credential_id
    }
  }
}

