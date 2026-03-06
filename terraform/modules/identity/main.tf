# ═══════════════════════════════════════════════════════════════════
# MODULE: identity
# Creates Azure AD groups and assigns subscription-level RBAC roles:
#   Groups:
#     - <company>-platform-admins    → Owner
#     - <company>-network-admins     → Network Contributor
#     - <company>-security-admins    → Security Admin
#     - <company>-devops-engineers   → Contributor
#     - <company>-developers         → Reader + specific scopes
#     - <company>-auditors           → Reader
# ═══════════════════════════════════════════════════════════════════

data "azuread_client_config" "current" {}

# ── Azure AD Groups ───────────────────────────────────────────────────
resource "azuread_group" "platform_admins" {
  display_name     = "${var.company_name}-platform-admins"
  security_enabled = true
  description      = "Platform administrators with Owner access"
}

resource "azuread_group" "network_admins" {
  display_name     = "${var.company_name}-network-admins"
  security_enabled = true
  description      = "Network administrators"
}

resource "azuread_group" "security_admins" {
  display_name     = "${var.company_name}-security-admins"
  security_enabled = true
  description      = "Security administrators"
}

resource "azuread_group" "devops_engineers" {
  display_name     = "${var.company_name}-devops-engineers"
  security_enabled = true
  description      = "DevOps engineers with Contributor access"
}

resource "azuread_group" "developers" {
  display_name     = "${var.company_name}-developers"
  security_enabled = true
  description      = "Developers with Reader access"
}

resource "azuread_group" "auditors" {
  display_name     = "${var.company_name}-auditors"
  security_enabled = true
  description      = "Auditors with Reader access"
}

# ── Subscription-level RBAC Assignments ──────────────────────────────
locals {
  sub_scope = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_role_assignment" "platform_admins_owner" {
  scope                = local.sub_scope
  role_definition_name = "Owner"
  principal_id         = azuread_group.platform_admins.object_id
}

resource "azurerm_role_assignment" "network_admins" {
  scope                = local.sub_scope
  role_definition_name = "Network Contributor"
  principal_id         = azuread_group.network_admins.object_id
}

resource "azurerm_role_assignment" "security_admins" {
  scope                = local.sub_scope
  role_definition_name = "Security Admin"
  principal_id         = azuread_group.security_admins.object_id
}

resource "azurerm_role_assignment" "devops_contributor" {
  scope                = local.sub_scope
  role_definition_name = "Contributor"
  principal_id         = azuread_group.devops_engineers.object_id
}

resource "azurerm_role_assignment" "developers_reader" {
  scope                = local.sub_scope
  role_definition_name = "Reader"
  principal_id         = azuread_group.developers.object_id
}

resource "azurerm_role_assignment" "auditors_reader" {
  scope                = local.sub_scope
  role_definition_name = "Reader"
  principal_id         = azuread_group.auditors.object_id
}

# ── Custom Role: LZ Operator ──────────────────────────────────────────
resource "azurerm_role_definition" "lz_operator" {
  name        = "LZ Operator - ${var.company_name} ${var.environment}"
  scope       = local.sub_scope
  description = "Can manage landing zone resources but not security or RBAC"

  permissions {
    actions = [
      "Microsoft.Compute/*",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Storage/*",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/deployments/*",
      "Microsoft.KeyVault/vaults/secrets/read",
    ]
    not_actions = [
      "Microsoft.Authorization/*/write",
      "Microsoft.Authorization/*/delete",
      "Microsoft.KeyVault/vaults/write",
      "Microsoft.KeyVault/vaults/delete",
    ]
  }

  assignable_scopes = [local.sub_scope]
}
