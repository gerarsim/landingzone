variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "org_id" {
  type        = string
  description = "GCP Organization ID. Required to apply org-level policy constraints. Leave empty to skip."
  default     = ""
}
