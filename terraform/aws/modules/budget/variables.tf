variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "monthly_budget" {
  type        = number
  description = "Monthly spend limit in USD."
}

variable "alert_email" {
  type        = string
  description = "Email address for budget alert notifications."
}
