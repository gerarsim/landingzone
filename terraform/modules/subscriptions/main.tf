# ═══════════════════════════════════════════════════════════════════
# MODULE: subscriptions
# Subscription vending: moves existing subscriptions into the right
# management group and applies baseline tags and role assignments.
#
# NOTE: Creating net-new subscriptions requires an EA/MCA billing
# account. This module handles placement and governance of
# subscriptions that already exist.
# ═══════════════════════════════════════════════════════════════════

# ── Move subscriptions to management groups ───────────────────────────
resource "azurerm_management_group_subscription_association" "subscriptions" {
  for_each            = var.subscriptions
  management_group_id = each.value.management_group_id
  subscription_id     = "/subscriptions/${each.value.subscription_id}"
}

# ── Apply baseline tags to each subscription's default RG ────────────
resource "azurerm_resource_group" "subscription_baseline" {
  for_each = var.subscriptions
  name     = "rg-${each.key}-baseline"
  location = var.location

  tags = merge(var.tags, {
    subscription_purpose = each.value.purpose
    owner                = each.value.owner
  })

  provider = azurerm
}

# ── Lock subscriptions from accidental deletion (prod only) ──────────
resource "azurerm_management_lock" "subscription_lock" {
  for_each   = { for k, v in var.subscriptions : k => v if v.lock == true }
  name       = "lock-${each.key}-dontdelete"
  scope      = "/subscriptions/${each.value.subscription_id}"
  lock_level = "CanNotDelete"
  notes      = "Managed by LZForge Terraform. Do not delete without approval."
}
