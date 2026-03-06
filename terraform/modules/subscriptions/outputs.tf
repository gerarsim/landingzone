output "onboarded_subscriptions" {
  value = { for k, v in azurerm_management_group_subscription_association.subscriptions : k => v.id }
}
