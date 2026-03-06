# ═══════════════════════════════════════════════════════════════════
# MODULE: security
# Deploys:
#   - Azure Key Vault (with soft-delete, purge protection)
#   - Microsoft Defender for Cloud (all plans)
#   - Security Center auto-provisioning (MMA/AMA agent)
#   - Azure Security Center contact
#   - Diagnostic settings for Key Vault → Log Analytics
# ═══════════════════════════════════════════════════════════════════

# ── Key Vault ─────────────────────────────────────────────────────────
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

# Key Vault Crypto Officer for terraform SP
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.object_id
}

# ── Key Vault Diagnostic Settings → Log Analytics ─────────────────────
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

# ── Microsoft Defender for Cloud ──────────────────────────────────────
locals {
  defender_plans = [
    "VirtualMachines",
    "SqlServers",
    "AppServices",
    "StorageAccounts",
    "Containers",
    "KeyVaults",
    "Dns",
    "Arm",
  ]
}

resource "azurerm_security_center_subscription_pricing" "plans" {
  for_each      = toset(local.defender_plans)
  resource_type = each.value
  tier          = var.defender_tier
}

# ── Security Center Contact ───────────────────────────────────────────
resource "azurerm_security_center_contact" "main" {
  email               = var.security_contact_email
  alert_notifications = true
  alerts_to_admins    = true
}

# ── Auto-provisioning: Azure Monitor Agent ────────────────────────────
resource "azurerm_security_center_auto_provisioning" "ama" {
  auto_provision = "On"
}

# ── Key Vault: Landing Zone shared secrets placeholder ────────────────
resource "azurerm_key_vault_secret" "lz_metadata" {
  name         = "lz-metadata"
  value        = jsonencode({
    company     = var.company_name
    environment = var.environment
    deployed_by = "velox-terraform"
  })
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.kv_admin]
  tags         = var.tags
}
