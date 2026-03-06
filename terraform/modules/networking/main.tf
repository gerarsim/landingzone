# ═══════════════════════════════════════════════════════════════════
# MODULE: networking
# Deploys a Hub-Spoke network topology:
#   Hub VNet
#   ├── GatewaySubnet          (VPN/ExpressRoute)
#   ├── AzureFirewallSubnet    (Azure Firewall)
#   ├── AzureBastionSubnet     (Bastion)
#   └── snet-management        (Jumpboxes, MGMT tools)
#   Spoke VNets (dynamic, from var.spoke_address_spaces)
#   └── Peered to hub (bidirectional)
# ═══════════════════════════════════════════════════════════════════

# ── Resource Groups ───────────────────────────────────────────────────
resource "azurerm_resource_group" "networking" {
  name     = "rg-${var.company_name}-network-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "security" {
  name     = "rg-${var.company_name}-security-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "ops" {
  name     = "rg-${var.company_name}-ops-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ── Hub VNet ──────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.environment}"
  address_space       = [var.hub_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = var.tags
}

# Gateway Subnet (required name, no NSG)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 0)]
}

# Azure Firewall Subnet (required name, no NSG)
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 1)]
}

# Azure Bastion Subnet (required name)
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 2)]
}

# Management Subnet
resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 3)]
}

# ── NSG: Management Subnet ────────────────────────────────────────────
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = var.tags

  security_rule {
    name                       = "allow-bastion-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = cidrsubnet(var.hub_address_space, 8, 2)  # Bastion subnet
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# ── Route Table: force traffic through Firewall ───────────────────────
resource "azurerm_route_table" "management" {
  name                          = "rt-management-${var.environment}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.networking.name
  disable_bgp_route_propagation = true
  tags                          = var.tags
}

resource "azurerm_subnet_route_table_association" "management" {
  subnet_id      = azurerm_subnet.management.id
  route_table_id = azurerm_route_table.management.id
}

# ── Azure Firewall (optional) ─────────────────────────────────────────
resource "azurerm_public_ip" "firewall" {
  count               = var.enable_firewall ? 1 : 0
  name                = "pip-firewall-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afw-hub-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "afw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

# Firewall: allow all outbound (tighten for prod)
resource "azurerm_firewall_network_rule_collection" "allow_outbound" {
  count               = var.enable_firewall ? 1 : 0
  name                = "allow-outbound"
  azure_firewall_name = azurerm_firewall.hub[0].name
  resource_group_name = azurerm_resource_group.networking.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-all-outbound"
    source_addresses      = ["10.0.0.0/8"]
    destination_addresses = ["*"]
    destination_ports     = ["*"]
    protocols             = ["Any"]
  }
}

# Route management traffic through firewall when enabled
resource "azurerm_route" "to_firewall" {
  count                  = var.enable_firewall ? 1 : 0
  name                   = "route-to-firewall"
  resource_group_name    = azurerm_resource_group.networking.name
  route_table_name       = azurerm_route_table.management.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
}

# ── Azure Bastion (optional) ──────────────────────────────────────────
resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-bastion-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bas-hub-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = var.tags

  ip_configuration {
    name                 = "bas-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# ── VPN Gateway (optional) ────────────────────────────────────────────
resource "azurerm_public_ip" "vpn_gateway" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "pip-vpngw-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Dynamic"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "hub" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "vgw-hub-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = false
  sku                 = "VpnGw1"
  tags                = var.tags

  ip_configuration {
    name                          = "vgw-ipconfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

# ── Spoke VNets (dynamic) ─────────────────────────────────────────────
resource "azurerm_virtual_network" "spoke" {
  for_each            = var.spoke_address_spaces
  name                = "vnet-spoke-${each.key}-${var.environment}"
  address_space       = [each.value]
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = var.tags
}

# Default subnet in each spoke
resource "azurerm_subnet" "spoke_default" {
  for_each             = var.spoke_address_spaces
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [cidrsubnet(each.value, 8, 0)]
}

# NSG for each spoke default subnet
resource "azurerm_network_security_group" "spoke" {
  for_each            = var.spoke_address_spaces
  name                = "nsg-spoke-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking.name
  tags                = var.tags

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each                  = var.spoke_address_spaces
  subnet_id                 = azurerm_subnet.spoke_default[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

# ── Hub → Spoke Peering ───────────────────────────────────────────────
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each                     = var.spoke_address_spaces
  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.networking.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.enable_vpn_gateway
  allow_virtual_network_access = true
}

# ── Spoke → Hub Peering ───────────────────────────────────────────────
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each                     = var.spoke_address_spaces
  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.networking.name
  virtual_network_name         = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.enable_vpn_gateway
  allow_virtual_network_access = true
}

# ── Private DNS Zone (Azure internal) ────────────────────────────────
resource "azurerm_private_dns_zone" "internal" {
  name                = "${var.company_name}.internal"
  resource_group_name = azurerm_resource_group.networking.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                  = "link-hub"
  resource_group_name   = azurerm_resource_group.networking.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = true
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "spokes" {
  for_each              = var.spoke_address_spaces
  name                  = "link-spoke-${each.key}"
  resource_group_name   = azurerm_resource_group.networking.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  registration_enabled  = false
  tags                  = var.tags
}
