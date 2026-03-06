output "landing_zone_summary" {
  description = "Summary of deployed Landing Zone resources"
  value = {
    management_group_id        = module.management_groups.landing_zone_mg_id
    hub_vnet_id                = module.networking.hub_vnet_id
    hub_vnet_address_space     = module.networking.hub_vnet_address_space
    spoke_vnet_ids             = module.networking.spoke_vnet_ids
    key_vault_uri              = module.security.key_vault_uri
    log_analytics_workspace_id = module.monitoring.workspace_id
    resource_groups            = module.networking.resource_group_names
    aad_groups                 = module.identity.aad_group_ids
  }
}

output "networking" {
  description = "Networking outputs"
  value = {
    hub_vnet_id          = module.networking.hub_vnet_id
    hub_vnet_name        = module.networking.hub_vnet_name
    spoke_vnet_ids       = module.networking.spoke_vnet_ids
    firewall_private_ip  = module.networking.firewall_private_ip
    bastion_public_ip    = module.networking.bastion_public_ip
  }
}

output "security" {
  description = "Security outputs"
  value = {
    key_vault_id   = module.security.key_vault_id
    key_vault_uri  = module.security.key_vault_uri
    defender_plans = module.security.defender_plans_enabled
  }
}

output "monitoring" {
  description = "Monitoring outputs"
  value = {
    workspace_id           = module.monitoring.workspace_id
    workspace_name         = module.monitoring.workspace_name
    action_group_id        = module.monitoring.action_group_id
  }
}

output "identity" {
  description = "Azure AD Group IDs for RBAC"
  value       = module.identity.aad_group_ids
}
