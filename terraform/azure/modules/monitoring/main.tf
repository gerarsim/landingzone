# ═══════════════════════════════════════════════════════════════════
# MODULE: monitoring
# Deploys:
#   - Log Analytics Workspace
#   - Storage Account (diagnostics archive)
#   - Action Group (email alerts)
#   - Activity Log Alerts (delete resources, policy changes, etc.)
#   - Azure Monitor Alert Rules
#   - Diagnostic settings for Activity Log → Workspace
# ═══════════════════════════════════════════════════════════════════

# ── Log Analytics Workspace ───────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.company_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# ── Log Analytics Solutions ───────────────────────────────────────────
locals {
  solutions = ["SecurityInsights", "AzureActivity", "VMInsights", "ContainerInsights"]
}

resource "azurerm_log_analytics_solution" "solutions" {
  for_each              = toset(local.solutions)
  solution_name         = each.value
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value}"
  }
}

# ── Storage Account (long-term archive) ───────────────────────────────
resource "azurerm_storage_account" "diagnostics" {
  name                     = "st${replace(var.company_name, "-", "")}diag${var.environment}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# ── Action Group (alerts → email) ─────────────────────────────────────
resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-ops-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "ops-alerts"
  tags                = var.tags

  email_receiver {
    name                    = "ops-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# ── Activity Log Alerts ───────────────────────────────────────────────
locals {
  subscription_scope = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
}

data "azurerm_subscription" "current" {}

# Alert: Resource group deleted
resource "azurerm_monitor_activity_log_alert" "rg_delete" {
  name                = "alert-rg-delete-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [local.subscription_scope]
  description         = "Triggered when a resource group is deleted"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Resources/subscriptions/resourcegroups/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Alert: Policy assignment changed
resource "azurerm_monitor_activity_log_alert" "policy_change" {
  name                = "alert-policy-change-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [local.subscription_scope]
  description         = "Triggered when a policy assignment is created or deleted"
  tags                = var.tags

  criteria {
    category       = "Policy"
    operation_name = "Microsoft.Authorization/policyAssignments/write"
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Alert: Security solution disabled
resource "azurerm_monitor_activity_log_alert" "security_disabled" {
  name                = "alert-security-disabled-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [local.subscription_scope]
  description         = "Triggered when a security solution is deleted"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Security/securitySolutions/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# Alert: Firewall deleted
resource "azurerm_monitor_activity_log_alert" "firewall_delete" {
  name                = "alert-firewall-delete-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [local.subscription_scope]
  description         = "Triggered when Azure Firewall is deleted"
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Network/azureFirewalls/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

# ── Azure Monitor: Subscription Activity Log → Workspace ─────────────
resource "azurerm_monitor_diagnostic_setting" "subscription_activity" {
  name               = "diag-activity-log-${var.environment}"
  target_resource_id = local.subscription_scope
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "ServiceHealth" }
  enabled_log { category = "Alert" }
  enabled_log { category = "Recommendation" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Autoscale" }
  enabled_log { category = "ResourceHealth" }
}
