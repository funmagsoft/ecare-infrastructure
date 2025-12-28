# Re-export outputs from the identity module
output "workload_identities" {
  description = "Map of workload identities per service"
  value       = module.environment.workload_identities
}
