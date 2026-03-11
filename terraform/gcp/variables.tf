# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Root Variables
# All values are written per-job into a .tfvars file by the worker.
# GCP credentials are passed as GOOGLE_* environment variables — never
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

variable "project_id" {
  type        = string
  description = "GCP Project ID where resources will be deployed."
}

variable "region" {
  type        = string
  description = "Primary GCP region for all resources."
  default     = "europe-west1"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the hub subnet."
  default     = "10.0.0.0/24"
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
  description = "Email address for budget alerts."
  default     = "ops@example.com"
}

variable "billing_account_id" {
  type        = string
  description = "GCP Billing Account ID (format: XXXXXX-XXXXXX-XXXXXX) for budget resources."
  default     = ""
}

variable "enable_cloud_nat" {
  type        = bool
  description = "Deploy Cloud NAT for private outbound internet access."
  default     = true
}

variable "enable_scc" {
  type        = bool
  description = "Enable Security Command Center (requires org-level permissions)."
  default     = false
}

variable "enable_cloud_armor" {
  type        = bool
  description = "Enable Cloud Armor WAF policy."
  default     = false
}
