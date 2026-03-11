# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Root Variables
# All values are written per-job into a .tfvars file by the worker.
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
  description = "CIDR block for the hub VPC."
  default     = "10.0.0.0/16"
}

variable "monthly_budget" {
  type        = number
  description = "Monthly spend limit in USD. Alert fires at 90% threshold."
  default     = 1000

  validation {
    condition     = var.monthly_budget >= 100 && var.monthly_budget <= 1000000
    error_message = "monthly_budget must be between 100 and 1,000,000."
  }
}

variable "alert_email" {
  type        = string
  description = "Email address for budget alerts and security findings."
  default     = "ops@example.com"
}

variable "enable_guardduty" {
  type        = bool
  description = "Enable AWS GuardDuty for threat detection."
  default     = true
}

variable "enable_cloudtrail" {
  type        = bool
  description = "Enable AWS CloudTrail for audit logging."
  default     = true
}

variable "enable_security_hub" {
  type        = bool
  description = "Enable AWS Security Hub for centralised security findings."
  default     = false
}
