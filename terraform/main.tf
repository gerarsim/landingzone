terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-velox-tfstate"
    storage_account_name = "veloxtfstate"
    container_name       = "tfstate"
    # key is injected per job: -backend-config=key=<job_id>.tfstate
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {}

data "azurerm_client_config" "current" {}

# ── 1. Management Groups ──────────────────────────────────────────────
module "management_groups" {
  source       = "./modules/management-groups"
  company_name = var.company_name
  environment  = var.environment
}

# ── 2. Policies ───────────────────────────────────────────────────────
module "policies" {
  source              = "./modules/policies"
  management_group_id = module.management_groups.landing_zone_mg_id
  environment         = var.environment
  location            = var.location
  depends_on          = [module.management_groups]
}

# ── 3. Identity & RBAC ────────────────────────────────────────────────
module "identity" {
  source          = "./modules/identity"
  company_name    = var.company_name
  environment     = var.environment
  subscription_id = data.azurerm_client_config.current.subscription_id
  tenant_id       = data.azurerm_client_config.current.tenant_id
}

# ── 4. Networking ─────────────────────────────────────────────────────
module "networking" {
  source               = "./modules/networking"
  company_name         = var.company_name
  environment          = var.environment
  location             = var.location
  hub_address_space    = var.hub_address_space
  spoke_address_spaces = var.spoke_address_spaces
  enable_firewall      = var.enable_firewall
  enable_vpn_gateway   = var.enable_vpn_gateway
  enable_bastion       = var.enable_bastion
  tags                 = local.common_tags
}

# ── 5. Security ───────────────────────────────────────────────────────
module "security" {
  source              = "./modules/security"
  company_name        = var.company_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.networking.security_rg_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  log_analytics_id    = module.monitoring.workspace_id
  tags                = local.common_tags
  depends_on          = [module.networking, module.monitoring]
}

# ── 6. Monitoring ─────────────────────────────────────────────────────
module "monitoring" {
  source              = "./modules/monitoring"
  company_name        = var.company_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.networking.ops_rg_name
  alert_email         = var.alert_email
  tags                = local.common_tags
  depends_on          = [module.networking]
}

# ── 7. Budget & Cost Controls ─────────────────────────────────────────
module "budget" {
  source          = "./modules/budget"
  company_name    = var.company_name
  environment     = var.environment
  subscription_id = data.azurerm_client_config.current.subscription_id
  monthly_budget  = var.monthly_budget
  alert_email     = var.alert_email
}

# ── Locals ────────────────────────────────────────────────────────────
locals {
  common_tags = {
    company     = var.company_name
    environment = var.environment
    managed_by  = "velox-terraform"
  }
}
