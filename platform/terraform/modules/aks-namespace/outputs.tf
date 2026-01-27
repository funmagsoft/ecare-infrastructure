output "namespace_names" {
  description = "Names of the created namespaces"
  value       = [for ns in kubernetes_namespace_v1.this : ns.metadata[0].name]
}
