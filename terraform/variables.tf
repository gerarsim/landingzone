# ═══════════════════════════════════════════════════════════════════
# VELOX — Root Variables
# All values are written per-job into a .tfvars file by the worker.
# ARM credentials are passed as ARM_* environment variables — never
# written into tfvars files to avoid secrets in state files.
# ═══════════════════════════════════════════════════════════════════

# ── Core ─────────────────────────────────────────────────────────────

variable "company_name" {
  type        = string
  description = "Company identifier — used in all resource names and management group hierarchy."

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

variable "location" {
  type        = string
  description = "Primary Azure region for all resources."
  default     = "westeurope"
}

# ── Identity (resolved at runtime via data source — not in tfvars) ───
# data.azurerm_client_config.current provides:
#   .subscription_id  .tenant_id  .object_id
# Variables below are passed by the worker for modules that need them
# explicitly (e.g. policies module).

variable "arm_subscription_id" {
  type        = string
  description = "Azure Subscription ID — passed by worker via tfvars."
  default     = ""
}

variable "arm_tenant_id" {
  type        = string
  description = "Azure Tenant ID — passed by worker via tfvars."
  default     = ""
}

# ── Networking ────────────────────────────────────────────────────────

variable "hub_address_space" {
  type        = string
  description = "CIDR for the hub VNet."
  default     = "10.0.0.0/16"
}

variable "spoke_address_spaces" {
  type        = map(string)
  description = "Map of spoke name → CIDR. Creates one spoke VNet per entry."
  default = {
    workloads = "10.1.0.0/16"
    dmz       = "10.2.0.0/16"
  }
}

variable "enable_firewall" {
  type        = bool
  description = "Deploy Azure Firewall in the hub VNet."
  default     = true
}

variable "enable_vpn_gateway" {
  type        = bool
  description = "Deploy VPN Gateway in the hub VNet (adds ~30 min to deploy time)."
  default     = false
}

variable "enable_bastion" {
  type        = bool
  description = "Deploy Azure Bastion for secure VM access."
  default     = true
}

# ── Monitoring ────────────────────────────────────────────────────────

variable "alert_email" {
  type        = string
  description = "Email address for budget alerts, activity log alerts, and security contacts."
  default     = "ops@example.com"
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics workspace retention in days."
  default     = 30
}

# ── Budget ────────────────────────────────────────────────────────────

variable "monthly_budget" {
  type        = number
  description = "Monthly spend limit in USD. Alerts fire at 50/75/90/100/110% thresholds."
  default     = 1000

  validation {
    condition     = var.monthly_budget >= 100 && var.monthly_budget <= 1000000
    error_message = "monthly_budget must be between 100 and 1,000,000."
  }
}

# ── Security ──────────────────────────────────────────────────────────

variable "defender_tier" {
  type        = string
  description = "Microsoft Defender for Cloud plan tier."
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard"], var.defender_tier)
    error_message = "defender_tier must be Free or Standard."
  }
}

# ── Policies ─────────────────────────────────────────────────────────

variable "allowed_locations" {
  type        = list(string)
  description = "List of allowed Azure regions enforced by Azure Policy."
  default     = ["westeurope", "northeurope", "uksouth", "ukwest"]
}
