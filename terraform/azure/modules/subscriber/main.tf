variable name {}
variable cidr_block {}
variable azure_region {}
variable lb_ip {}
variable remote_vnet_name {}
variable remote_vnet_id {}
variable remote_rg_name {}
variable management_prefix {}
variable public_prefix {}
variable public_rt {}
variable management_rt {}

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.azure_region
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.name}-VNet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.cidr_block]
}

resource "azurerm_virtual_network_peering" "this-to-transit" {
    name                      = "${var.name}-to-transit"
    resource_group_name       = azurerm_resource_group.this.name
    virtual_network_name      = azurerm_virtual_network.this.name
    remote_virtual_network_id = var.remote_vnet_id
    allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "transit-to-this" {
    name                      = "transit-to-${var.name}"
    resource_group_name       = var.remote_rg_name
    virtual_network_name      = var.remote_vnet_name
    remote_virtual_network_id = azurerm_virtual_network.this.id
}


# This module figures out how many bits to add to get a /24. Also supports smaller subnets if the starting
# network is smaller than a /25. In that case it will divide it into two subnets.
module "newbits" {
  source = "../subnetting/"
  cidr_block = azurerm_virtual_network.this.address_space[0]
}

resource "azurerm_subnet" "this" {
  name                 = "Server"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(azurerm_virtual_network.this.address_space[0], module.newbits.newbits, 0)]
}

resource "azurerm_route_table" "this" {
    name                  = "${var.name}-Server"
    resource_group_name   = azurerm_resource_group.this.name
    location              = azurerm_resource_group.this.location
    disable_bgp_route_propagation = false
}

resource "azurerm_route" "blackhole_management" {
  name                = "Blackhole-Management"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.this.name
  address_prefix      = var.management_prefix
  next_hop_type       = "None"
}

resource "azurerm_route" "blackhole_public" {
  name                = "Blackhole-Public"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.this.name
  address_prefix      = var.public_prefix
  next_hop_type       = "None"
}

resource "azurerm_route" "default" {
  name                      = "UDR-default"
  resource_group_name       = azurerm_resource_group.this.name
  route_table_name          = azurerm_route_table.this.name
  address_prefix            = "0.0.0.0/0"
  next_hop_type             = "VirtualAppliance"
  next_hop_in_ip_address    = var.lb_ip #azurerm_lb.internal_lb.private_ip_address
}

resource "azurerm_subnet_route_table_association" "this" {
  subnet_id      = azurerm_subnet.this.id
  route_table_id = azurerm_route_table.this.id
}

resource "azurerm_route" "blackhole_public_to_this" {
  name                = "Blackhole-${var.name}"
  resource_group_name = var.remote_rg_name
  route_table_name    = var.public_rt #azurerm_route_table.private.name
  address_prefix      = azurerm_virtual_network.this.address_space[0]
  next_hop_type       = "None"
}

resource "azurerm_route" "blackhole_management_to_this" {
  name                = "Blackhole-${var.name}"
  resource_group_name = var.remote_rg_name
  route_table_name    = var.management_rt #azurerm_route_table.private.name
  address_prefix      = azurerm_virtual_network.this.address_space[0]
  next_hop_type       = "None"
}

output "rg_name" {
  value = azurerm_resource_group.this.name
}

output "rg_location" {
  value = azurerm_resource_group.this.location
}

output "subnet_id" {
  value = azurerm_subnet.this.id
}

output "subnet_cidr" {
  value = azurerm_subnet.this.address_prefix
}

