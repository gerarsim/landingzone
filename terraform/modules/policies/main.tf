# ═══════════════════════════════════════════════════════════════════
# MODULE: policies
# Assigns Azure built-in policies and custom initiatives:
#   - Require tags
#   - Allowed locations
#   - Deny public IP
#   - Require HTTPS on storage
#   - Defender for Cloud (ASC)
#   - Audit unencrypted disks
#   - Audit missing NSG
# ═══════════════════════════════════════════════════════════════════

# ── Custom Policy Initiative (set) ───────────────────────────────────
resource "azurerm_policy_set_definition" "landing_zone_baseline" {
  name         = "lz-baseline-${var.environment}"
  policy_type  = "Custom"
  display_name = "Landing Zone Baseline Policies (${var.environment})"
  description  = "Baseline governance policies for the landing zone"

  management_group_id = var.management_group_id

  # Require environment tag
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    reference_id         = "require-environment-tag"
    parameter_values = jsonencode({
      tagName = { value = "environment" }
    })
  }

  # Require managed-by tag
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    reference_id         = "require-managed-by-tag"
    parameter_values = jsonencode({
      tagName = { value = "managed_by" }
    })
  }

  # Audit VMs without managed disks
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
    reference_id         = "audit-vm-unmanaged-disks"
  }

  # Audit storage accounts allowing HTTP
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    reference_id         = "audit-storage-https"
  }

  # Audit missing NSG on subnets
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e71308d3-144b-4262-b144-efdc3cc90517"
    reference_id         = "audit-subnet-nsg"
  }

  # Audit unencrypted VM disks
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d"
    reference_id         = "audit-vm-disk-encryption"
  }
}

# ── Assign the initiative ─────────────────────────────────────────────
resource "azurerm_management_group_policy_assignment" "baseline" {
  name                 = "lz-baseline"
  display_name         = "LZ Baseline Governance"
  policy_definition_id = azurerm_policy_set_definition.landing_zone_baseline.id
  management_group_id  = var.management_group_id
}

# ── Allowed Locations ─────────────────────────────────────────────────
resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Azure Locations"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  management_group_id  = var.management_group_id

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}

# ── Deny Public IPs (on Corp landing zone pattern) ────────────────────
resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  name                 = "deny-public-ip"
  display_name         = "Deny Public IP addresses"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
  management_group_id  = var.management_group_id
  enforce              = var.environment == "prod" ? true : false
}

# ── Require HTTPS on Storage Accounts ────────────────────────────────
resource "azurerm_management_group_policy_assignment" "storage_https" {
  name                 = "storage-require-https"
  display_name         = "Require HTTPS on Storage Accounts"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  management_group_id  = var.management_group_id
  enforce              = true
}

# ── Defender for Cloud - Enable MCSB ─────────────────────────────────
resource "azurerm_management_group_policy_assignment" "mcsb" {
  name                 = "mcsb"
  display_name         = "Microsoft Cloud Security Benchmark"
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  management_group_id  = var.management_group_id

  identity {
    type = "SystemAssigned"
  }

  location = var.location
}
