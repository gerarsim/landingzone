data "azuread_client_config" "current" {}

locals {
  sub_scope = "/subscriptions/${var.subscription_id}"
}

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
