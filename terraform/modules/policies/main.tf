resource "azurerm_policy_set_definition" "landing_zone_baseline" {
  name         = "lz-baseline-${var.environment}"
  policy_type  = "Custom"
  display_name = "Landing Zone Baseline Policies (${var.environment})"
  description  = "Baseline governance policies for the landing zone"

  management_group_id = var.management_group_id

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    reference_id         = "require-environment-tag"
    parameter_values     = jsonencode({ tagName = { value = "environment" } })
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
    reference_id         = "require-managed-by-tag"
    parameter_values     = jsonencode({ tagName = { value = "managed_by" } })
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
    reference_id         = "audit-vm-unmanaged-disks"
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    reference_id         = "audit-storage-https"
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e71308d3-144b-4262-b144-efdc3cc90517"
    reference_id         = "audit-subnet-nsg"
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d"
    reference_id         = "audit-vm-disk-encryption"
  }
}

resource "azurerm_management_group_policy_assignment" "baseline" {
  name                 = "lz-baseline"
  display_name         = "LZ Baseline Governance"
  policy_definition_id = azurerm_policy_set_definition.landing_zone_baseline.id
  management_group_id  = var.management_group_id
}

resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed Azure Locations"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  management_group_id  = var.management_group_id
  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

resource "azurerm_management_group_policy_assignment" "storage_https" {
  name                 = "storage-require-https"
  display_name         = "Require HTTPS on Storage Accounts"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  management_group_id  = var.management_group_id
  enforce              = true
}
