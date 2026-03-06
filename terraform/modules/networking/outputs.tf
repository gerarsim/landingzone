output "hub_vnet_id"            { value = azurerm_virtual_network.hub.id }
output "hub_vnet_name"          { value = azurerm_virtual_network.hub.name }
output "hub_vnet_address_space" { value = azurerm_virtual_network.hub.address_space }
output "security_rg_name"       { value = azurerm_resource_group.security.name }
output "ops_rg_name"            { value = azurerm_resource_group.ops.name }
output "networking_rg_name"     { value = azurerm_resource_group.networking.name }

output "spoke_vnet_ids" {
  value = { for k, v in azurerm_virtual_network.spoke : k => v.id }
}

output "resource_group_names" {
  value = {
    networking = azurerm_resource_group.networking.name
    security   = azurerm_resource_group.security.name
    ops        = azurerm_resource_group.ops.name
  }
}

output "firewall_private_ip" {
  value = var.enable_firewall ? azurerm_firewall.hub[0].ip_configuration[0].private_ip_address : null
}

output "bastion_public_ip" {
  value = var.enable_bastion ? azurerm_public_ip.bastion[0].ip_address : null
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.internal.id
}

output "management_subnet_id" {
  value = azurerm_subnet.management.id
}
