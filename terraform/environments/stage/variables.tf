variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stage"
}

variable "organization_name" {
  description = "Organization name for resource naming"
  type        = string
  default     = "hycom"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecare"
}
