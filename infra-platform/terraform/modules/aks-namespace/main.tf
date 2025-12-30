#------------------------------------------------------------------------------
# Kubernetes Namespace
#------------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace

    labels = merge(
      {
        "app.kubernetes.io/name"       = var.namespace
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = var.project_name
        "app.kubernetes.io/env"        = var.environment
      },
      var.labels
    )
  }
}
