# ═══════════════════════════════════════════════════════════════════
# MODULE: security
# Deploys:
#   - Azure Key Vault (with soft-delete, purge protection)
#   - Diagnostic settings for Key Vault → Log Analytics
#
# NOTE: Defender for Cloud (azurerm_security_center_subscription_pricing)
# and Security Center Contact are subscription-level singletons.
# They are managed outside this module to avoid conflicts across jobs.
# ═══════════════════════════════════════════════════════════════════

resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.company_name}-${var.environment}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
  enable_rbac_authorization  = true
  tags                       = var.tags

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.key_vault_allowed_ips
    virtual_network_subnet_ids = var.key_vault_allowed_subnet_ids
  }
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.object_id
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-kv-${var.environment}"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "AuditEvent" }
  enabled_log { category = "AzurePolicyEvaluationDetails" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_key_vault_secret" "lz_metadata" {
  name         = "lz-metadata"
  value        = jsonencode({
    company     = var.company_name
    environment = var.environment
    deployed_by = "lzforge-terraform"
  })
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_admin]
  tags         = var.tags
}
