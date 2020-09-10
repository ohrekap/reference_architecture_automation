terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "azurerm" {
  version = "=2.24.0"
  features {}
}

locals {
  name = "${var.deployment_name != "" ? "${var.deployment_name}-${var.vpc_name}" : var.vpc_name}"
  deployment_name = "${var.deployment_name != "" ? "${var.deployment_name}" : ""}"

}

resource "azurerm_resource_group" "this" {
  name     = local.name
  location = var.azure_region
}

resource "azurerm_virtual_network" "this" {
  name                = local.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vpc_cidr_block]
}

# This module figures out how many bits to add to get a /24. Also supports smaller subnets if the starting
# network is smaller than a /25. In that case it will divide it into two subnets.
module "newbits" {
  source = "../modules/subnetting/"
  cidr_block = azurerm_virtual_network.this.address_space[0]
}

resource "azurerm_subnet" "this" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(azurerm_virtual_network.this.address_space[0], module.newbits.newbits, 0)]
}

resource "azurerm_network_security_group" "subnet" {
  name                = "AllowManagement-Subnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_network_security_rule" "https" {
  name                        = "AllowHTTPS-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.onprem_IPaddress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.subnet.name
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "AllowSSH-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.onprem_IPaddress
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.subnet.name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.subnet.id
}

resource "azurerm_network_security_group" "nic" {
  name                = "AllowAll-NIC"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_network_security_rule" "all" {
  name                        = "AllowAll-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.nic.name
}

resource "azurerm_storage_account" "this" {
  name                     = "${local.deployment_name}managementv2diag"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_availability_set" "this" {
  name                        = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  # https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/managed-disks-common-fault-domain-region-list.md
  platform_fault_domain_count = 2
}

module "panorama" {
  source = "../modules/panorama/"
  deployment_name = local.deployment_name
  resource_group_name = azurerm_resource_group.this.name
  resource_group_location =azurerm_resource_group.this.location
  subnet_id = azurerm_subnet.this.id
  subnet_prefix = azurerm_subnet.this.address_prefixes[0]
  availability_set_id = azurerm_availability_set.this.id
  password = var.password
  diag_sa = azurerm_storage_account.this.primary_blob_endpoint
  enable_ha = var.enable_ha
}

output "primary_eip" {
  value = module.panorama.primary_ip
}

output "secondary_eip" {
  value = module.panorama.secondary_ip
}

output "primary_private_ip" {
  value = module.panorama.primary_private_ip
}

output "secondary_private_ip" {
  value = module.panorama.secondary_private_ip
}

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "rg" {
  value = azurerm_resource_group.this.name
}

output "cidr" {
  value = azurerm_virtual_network.this.address_space
}