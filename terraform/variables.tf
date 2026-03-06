# ── Core ──────────────────────────────────────────────────────────────
variable "company_name" {
  description = "Short company identifier (lowercase, no spaces, 2-20 chars)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.company_name))
    error_message = "company_name must be 2-20 lowercase alphanumeric characters or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "westeurope"
}

# ── Networking ────────────────────────────────────────────────────────
variable "hub_address_space" {
  description = "CIDR block for the Hub VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_address_spaces" {
  description = "Map of spoke VNet names to CIDR blocks"
  type        = map(string)
  default = {
    workloads = "10.1.0.0/16"
    dmz       = "10.2.0.0/16"
  }
}

variable "enable_firewall" {
  description = "Deploy Azure Firewall in the hub"
  type        = bool
  default     = false  # set true for prod
}

variable "enable_vpn_gateway" {
  description = "Deploy VPN Gateway in the hub"
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Deploy Azure Bastion for secure VM access"
  type        = bool
  default     = true
}

# ── Alerts & Cost ─────────────────────────────────────────────────────
variable "alert_email" {
  description = "Email address for monitoring and budget alerts"
  type        = string
  default     = "ops@example.com"
}

variable "monthly_budget" {
  description = "Monthly budget in USD"
  type        = number
  default     = 1000
}
