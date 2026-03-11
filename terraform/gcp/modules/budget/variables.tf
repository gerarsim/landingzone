variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "monthly_budget" {
  type        = number
  description = "Monthly spend limit in USD."
}

variable "billing_account_id" {
  type        = string
  description = "GCP Billing Account ID (format: XXXXXX-XXXXXX-XXXXXX). Required for budget creation."
  default     = ""
}

variable "project_number" {
  type        = string
  description = "GCP Project number (not ID) for budget scope."
  default     = ""
}

variable "notification_channel_ids" {
  type        = list(string)
  description = "Cloud Monitoring notification channel IDs for budget alerts."
  default     = []
}
