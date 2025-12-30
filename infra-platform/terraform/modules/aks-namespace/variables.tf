variable "namespace" {
  description = "Kubernetes namespace to create"
  type        = string
  default     = "ecare"
}

variable "environment" {
  description = "Environment name (dev, test, stage, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for labeling"
  type        = string
  default     = "ecare"
}

variable "labels" {
  description = "Additional labels to apply to the namespace"
  type        = map(string)
  default     = {}
}
