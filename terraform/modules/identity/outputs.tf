output "aad_group_ids" {
  value = {}
}

output "lz_operator_role_id" {
  value = azurerm_role_definition.lz_operator.role_definition_resource_id
}
