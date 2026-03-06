output "landing_zone_mg_id" {
  description = "Top-level Landing Zone management group ID"
  value       = azurerm_management_group.landingzones.id
}

output "company_mg_id" {
  description = "Company root management group ID"
  value       = azurerm_management_group.company.id
}

output "platform_mg_id" {
  value = azurerm_management_group.platform.id
}

output "lz_corp_mg_id" {
  value = azurerm_management_group.lz_corp.id
}

output "lz_online_mg_id" {
  value = azurerm_management_group.lz_online.id
}

output "sandbox_mg_id" {
  value = azurerm_management_group.sandbox.id
}

output "all_mg_ids" {
  description = "Map of all management group IDs"
  value = {
    company          = azurerm_management_group.company.id
    platform         = azurerm_management_group.platform.id
    platform_identity    = azurerm_management_group.platform_identity.id
    platform_management  = azurerm_management_group.platform_management.id
    platform_connectivity = azurerm_management_group.platform_connectivity.id
    landingzones     = azurerm_management_group.landingzones.id
    lz_corp          = azurerm_management_group.lz_corp.id
    lz_online        = azurerm_management_group.lz_online.id
    sandbox          = azurerm_management_group.sandbox.id
    decommissioned   = azurerm_management_group.decommissioned.id
  }
}
