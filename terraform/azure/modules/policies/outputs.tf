output "initiative_id" {
  value = azurerm_policy_set_definition.landing_zone_baseline.id
}
output "assignments" {
  value = {
    baseline          = azurerm_management_group_policy_assignment.baseline.id
    allowed_locations = azurerm_management_group_policy_assignment.allowed_locations.id
    storage_https     = azurerm_management_group_policy_assignment.storage_https.id
  }
}
