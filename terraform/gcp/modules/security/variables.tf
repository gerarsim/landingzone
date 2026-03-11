variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "region" {
  type        = string
  description = "GCP region for KMS key ring."
}

variable "enable_cloud_armor" {
  type        = bool
  description = "Deploy Cloud Armor WAF security policy."
  default     = false
}

variable "enable_scc" {
  type        = bool
  description = "Enable Security Command Center (requires org-level permissions)."
  default     = false
}
