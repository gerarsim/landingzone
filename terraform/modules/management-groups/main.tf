# ═══════════════════════════════════════════════════════════════════
# MODULE: management-groups
# Creates a 3-level Management Group hierarchy:
#   Root Tenant
#   └── <company> (top-level)
#       ├── platform
#       │   ├── identity
#       │   ├── management
#       │   └── connectivity
#       ├── landingzones
#       │   ├── corp
#       │   └── online
#       └── sandbox
# ═══════════════════════════════════════════════════════════════════

# ── Top-level company group ───────────────────────────────────────────
resource "azurerm_management_group" "company" {
  display_name = var.company_name
}

# ── Platform ──────────────────────────────────────────────────────────
resource "azurerm_management_group" "platform" {
  display_name               = "${var.company_name}-platform"
  parent_management_group_id = azurerm_management_group.company.id
}

resource "azurerm_management_group" "platform_identity" {
  display_name               = "identity"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "platform_management" {
  display_name               = "management"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "platform_connectivity" {
  display_name               = "connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
}

# ── Landing Zones ─────────────────────────────────────────────────────
resource "azurerm_management_group" "landingzones" {
  display_name               = "${var.company_name}-landingzones"
  parent_management_group_id = azurerm_management_group.company.id
}

resource "azurerm_management_group" "lz_corp" {
  display_name               = "corp"
  parent_management_group_id = azurerm_management_group.landingzones.id
}

resource "azurerm_management_group" "lz_online" {
  display_name               = "online"
  parent_management_group_id = azurerm_management_group.landingzones.id
}

# ── Sandbox ───────────────────────────────────────────────────────────
resource "azurerm_management_group" "sandbox" {
  display_name               = "${var.company_name}-sandbox"
  parent_management_group_id = azurerm_management_group.company.id
}

# ── Decommissioned ────────────────────────────────────────────────────
resource "azurerm_management_group" "decommissioned" {
  display_name               = "${var.company_name}-decommissioned"
  parent_management_group_id = azurerm_management_group.company.id
}
