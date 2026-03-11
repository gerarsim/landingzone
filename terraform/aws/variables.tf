# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Root Variables
# All values written per-job by the worker into a .tfvars file.
# AWS credentials are passed as AWS_* environment variables — never
# written into tfvars files to avoid secrets in state files.
# ═══════════════════════════════════════════════════════════════════

variable "company_name" {
  type        = string
  description = "Company identifier — used in all resource names."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]{1,18}[a-z0-9]$", var.company_name))
    error_message = "company_name must be 3-20 lowercase alphanumeric characters or hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment (prod, dev, staging, test, uat)."

  validation {
    condition     = contains(["prod", "dev", "staging", "test", "uat"], var.environment)
    error_message = "environment must be one of: prod, dev, staging, test, uat."
  }
}

variable "region" {
  type        = string
  description = "Primary AWS region for all resources."
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days."
  default     = 90
}

variable "monthly_budget" {
  type        = number
  description = "Monthly spend limit in USD. Alerts fire at 50/75/90/100/110%."
  default     = 1000

  validation {
    condition     = var.monthly_budget >= 100 && var.monthly_budget <= 1000000
    error_message = "monthly_budget must be between 100 and 1,000,000."
  }
}

variable "alert_email" {
  type        = string
  description = "Email address for budget alerts, security findings, and CloudWatch alarms."
  default     = "ops@example.com"
}

variable "enable_guardduty" {
  type        = bool
  description = "Enable AWS GuardDuty threat detection."
  default     = true
}

variable "enable_cloudtrail" {
  type        = bool
  description = "Enable AWS CloudTrail multi-region audit logging."
  default     = true
}

variable "enable_security_hub" {
  type        = bool
  description = "Enable AWS Security Hub with CIS benchmark and AWS Foundational standards."
  default     = false
}
