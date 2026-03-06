output "aad_group_ids" {
  description = "Map of AAD group names to object IDs"
  value = {
    platform_admins  = azuread_group.platform_admins.object_id
    network_admins   = azuread_group.network_admins.object_id
    security_admins  = azuread_group.security_admins.object_id
    devops_engineers = azuread_group.devops_engineers.object_id
    developers       = azuread_group.developers.object_id
    auditors         = azuread_group.auditors.object_id
  }
}

output "lz_operator_role_id" {
  value = azurerm_role_definition.lz_operator.role_definition_resource_id
}
