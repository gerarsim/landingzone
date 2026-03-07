# ═══════════════════════════════════════════════════════════════════
# VELOX — Azure Landing Zone Root Module
# Wires all sub-modules in dependency order:
#   1. management-groups   (MG hierarchy)
#   2. networking          (Hub-Spoke VNets, Firewall, Bastion, VPN GW)
#   3. monitoring          (Log Analytics, Storage, Action Groups, Alerts)
#   4. security            (Key Vault, Defender for Cloud)
#   5. identity            (AAD Groups, RBAC, Custom Role)
#   6. policies            (Policy Initiatives, Assignments)
#   7. budget              (Subscription Budget with alert tiers)
# ═══════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }

  # Backend configured via -backend-config flags at runtime (per-job)
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  # ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID
  # are injected as environment variables per-job by the worker.
}

provider "azuread" {
  # Uses the same ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID
}

# ── Current context (SP object_id, subscription_id, tenant_id) ───────
data "azurerm_client_config" "current" {}

# ── Common tags applied to all resources ─────────────────────────────
locals {
  tags = {
    environment  = var.environment
    company      = var.company_name
    managed_by   = "velox-terraform"
    deployed_at  = timestamp()
  }
}

# ═══════════════════════════════════════════════════════════════════
# 1. MANAGEMENT GROUPS
# ═══════════════════════════════════════════════════════════════════
module "management_groups" {
  source = "./modules/management-groups"

  company_name = var.company_name
  environment  = var.environment
}

# ═══════════════════════════════════════════════════════════════════
# 2. NETWORKING  (Hub-Spoke topology)
# ═══════════════════════════════════════════════════════════════════
module "networking" {
  source = "./modules/networking"

  company_name         = var.company_name
  environment          = var.environment
  location             = var.location
  hub_address_space    = var.hub_address_space
  spoke_address_spaces = var.spoke_address_spaces
  enable_firewall      = var.enable_firewall
  enable_vpn_gateway   = var.enable_vpn_gateway
  enable_bastion       = var.enable_bastion
  tags                 = local.tags
}

# ═══════════════════════════════════════════════════════════════════
# 3. MONITORING  (depends on networking RGs)
# ═══════════════════════════════════════════════════════════════════
module "monitoring" {
  source = "./modules/monitoring"

  company_name        = var.company_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.networking.ops_rg_name
  alert_email         = var.alert_email
  log_retention_days  = var.log_retention_days
  tags                = local.tags

  depends_on = [module.networking]
}

# ═══════════════════════════════════════════════════════════════════
# 4. SECURITY  (Key Vault + Defender — depends on monitoring workspace)
# ═══════════════════════════════════════════════════════════════════
module "security" {
  source = "./modules/security"

  company_name           = var.company_name
  environment            = var.environment
  location               = var.location
  resource_group_name    = module.networking.security_rg_name
  tenant_id              = data.azurerm_client_config.current.tenant_id
  object_id              = data.azurerm_client_config.current.object_id
  log_analytics_id       = module.monitoring.workspace_id
  security_contact_email = var.alert_email
  defender_tier          = var.defender_tier

  key_vault_allowed_subnet_ids = [
    module.networking.management_subnet_id,
  ]

  tags = local.tags

  depends_on = [module.monitoring]
}

# ═══════════════════════════════════════════════════════════════════
# 5. IDENTITY  (AAD Groups + RBAC)
# ═══════════════════════════════════════════════════════════════════
module "identity" {
  source = "./modules/identity"

  company_name    = var.company_name
  environment     = var.environment
  subscription_id = data.azurerm_client_config.current.subscription_id
  tenant_id       = data.azurerm_client_config.current.tenant_id
}

# ═══════════════════════════════════════════════════════════════════
# 6. POLICIES  (Governance initiatives on Management Groups)
# ═══════════════════════════════════════════════════════════════════
module "policies" {
  source = "./modules/policies"

  management_group_id = module.management_groups.company_mg_id
  environment         = var.environment
  location            = var.location
  allowed_locations   = var.allowed_locations

  depends_on = [module.management_groups]
}

# ═══════════════════════════════════════════════════════════════════
# 7. BUDGET  (Subscription-level spend alerts)
# ═══════════════════════════════════════════════════════════════════
module "budget" {
  source = "./modules/budget"

  company_name    = var.company_name
  environment     = var.environment
  subscription_id = data.azurerm_client_config.current.subscription_id
  monthly_budget  = var.monthly_budget
  alert_email     = var.alert_email
}
