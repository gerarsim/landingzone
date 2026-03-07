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

  backend "azurerm" {}
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

provider "azuread" {}

data "azurerm_client_config" "current" {}

locals {
  tags = {
    environment = var.environment
    company     = var.company_name
    managed_by  = "velox-terraform"
  }
}

# Management groups and policies require elevated MG permissions
# Enable once SP has Owner on root Management Group
# module "management_groups" { ... }
# module "policies" { ... }

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
  tags                 = local.tags
}

module "monitoring" {
  source              = "./modules/monitoring"
  company_name        = var.company_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.networking.ops_rg_name
  alert_email         = var.alert_email
  log_retention_days  = var.log_retention_days
  tags                = local.tags
  depends_on          = [module.networking]
}

module "security" {
  source                       = "./modules/security"
  company_name                 = var.company_name
  environment                  = var.environment
  location                     = var.location
  resource_group_name          = module.networking.security_rg_name
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  object_id                    = data.azurerm_client_config.current.object_id
  log_analytics_id             = module.monitoring.workspace_id
  security_contact_email       = var.alert_email
  defender_tier                = var.defender_tier
  key_vault_allowed_subnet_ids = [module.networking.management_subnet_id]
  tags                         = local.tags
  depends_on                   = [module.monitoring]
}

module "identity" {
  source          = "./modules/identity"
  company_name    = var.company_name
  environment     = var.environment
  subscription_id = data.azurerm_client_config.current.subscription_id
  tenant_id       = data.azurerm_client_config.current.tenant_id
}

module "budget" {
  source          = "./modules/budget"
  company_name    = var.company_name
  environment     = var.environment
  subscription_id = data.azurerm_client_config.current.subscription_id
  monthly_budget  = var.monthly_budget
  alert_email     = var.alert_email
}
