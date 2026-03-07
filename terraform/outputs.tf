output "hub_vnet_id" {
  value = module.networking.hub_vnet_id
}

output "spoke_vnet_ids" {
  value = module.networking.spoke_vnet_ids
}

output "resource_groups" {
  value = module.networking.resource_group_names
}

output "log_analytics_workspace_id" {
  value = module.monitoring.workspace_id
}

output "log_analytics_workspace_name" {
  value = module.monitoring.workspace_name
}

output "key_vault_id" {
  value = module.security.key_vault_id
}

output "key_vault_uri" {
  value = module.security.key_vault_uri
}

output "key_vault_name" {
  value = module.security.key_vault_name
}

output "aad_group_ids" {
  value = module.identity.aad_group_ids
}

output "budget_id" {
  value = module.budget.budget_id
}

output "landing_zone_summary" {
  value = {
    company        = var.company_name
    environment    = var.environment
    location       = var.location
    key_vault      = module.security.key_vault_name
    log_analytics  = module.monitoring.workspace_name
    hub_vnet       = module.networking.hub_vnet_name
    monthly_budget = var.monthly_budget
  }
}
