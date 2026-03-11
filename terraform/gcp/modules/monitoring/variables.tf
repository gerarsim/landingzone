variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "region" {
  type        = string
  description = "GCP region for the audit log storage bucket."
}

variable "alert_email" {
  type        = string
  description = "Email address for alert notifications."
}
