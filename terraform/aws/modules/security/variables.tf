variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "enable_guardduty" {
  type        = bool
  description = "Enable AWS GuardDuty threat detection."
  default     = true
}

variable "enable_security_hub" {
  type        = bool
  description = "Enable AWS Security Hub + CIS benchmark."
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days."
  default     = 90
}

variable "alert_email" {
  type        = string
  description = "Email for security finding notifications."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
