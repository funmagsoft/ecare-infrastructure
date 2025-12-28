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

