#------------------------------------------------------------------------------
# Kubernetes Namespace
#------------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "this" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.key

    labels = merge(
      {
        "app.kubernetes.io/name"       = each.key
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = var.project_name
        "app.kubernetes.io/env"        = var.environment
      },
      var.labels
    )
  }
}
