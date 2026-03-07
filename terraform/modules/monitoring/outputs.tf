output "workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}
output "workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}
output "workspace_key" {
  value     = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive = true
}
output "storage_account_id" {
  value = azurerm_storage_account.diagnostics.id
}
output "action_group_id" {
  value = azurerm_monitor_action_group.ops.id
}