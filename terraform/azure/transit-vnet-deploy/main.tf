terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "azurerm" {
  version = "=2.24.0"
  features {}
}

provider "panos" {
    hostname = data.terraform_remote_state.panorama.outputs.primary_eip
    version = "~> 1.6"
}

provider "null" {
  version = "~> 2.1"
}

locals {
  name = "${var.deployment_name != "" ? "${var.deployment_name}-${var.vpc_name}" : var.vpc_name}"
  deployment_name = "${var.deployment_name != "" ? "${var.deployment_name}" : ""}"
  private-block = cidrsubnet(var.vpc_cidr_block, 1, 0)
  public-block = cidrsubnet(var.vpc_cidr_block, 1, 1)
  vmseriesVersion = "9.1.3"
  # I am defining the commands here because if you do it in the null provisioner then it won't adjust the configuration if you make a change to the command.
  # Defining it as a local variable allows for the provisioner to use this variable as a trigger
  # The authcodes file must have a . at the end. Otherwise Azure thinks it is a directory
  bootstrap_local-exec = <<-EOF
    echo "type=dhcp-client
    panorama-server=${data.terraform_remote_state.panorama.outputs.primary_private_ip}
    panorama-server=${data.terraform_remote_state.panorama.outputs.secondary_private_ip}
    tplname=${panos_panorama_template_stack.obew.name}
    dgname=${panos_panorama_device_group.obew.name}
    dns-primary=168.63.129.16
    vm-auth-key=${var.panorama_bootstrap_key}
    dhcp-accept-server-hostname=yes
    dhcp-accept-server-domain=yes" > init-cfg.txt && az storage file upload \
    --account-name ${azurerm_storage_account.this.name} \
    --account-key ${azurerm_storage_account.this.primary_access_key} \
    --share-name ${azurerm_storage_share.this.name} \
    --source "init-cfg.txt" \
    --path "${azurerm_storage_share_directory.obew-config.name}/init-cfg.txt" \
    && rm init-cfg.txt && echo "${var.authcode}" > authcodes && az storage file upload \
    --account-name ${azurerm_storage_account.this.name} \
    --account-key ${azurerm_storage_account.this.primary_access_key} \
    --share-name ${azurerm_storage_share.this.name} \
    --source "authcodes" \
    --path "${azurerm_storage_share_directory.obew-license.name}/authcodes." \
    && rm authcodes
    EOF
}
data "terraform_remote_state" "panorama" {
  backend = "local"

  config = {
    path = "../panorama/terraform.tfstate"
  }
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
  cidr_block = local.private-block
}

resource "azurerm_subnet" "management" {
  name                 = "Transit-Management"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(local.public-block, module.newbits.newbits, 127)]
}

resource "azurerm_subnet" "private" {
  name                 = "Transit-Private"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(local.private-block, module.newbits.newbits, 0)]
}

resource "azurerm_subnet" "public" {
  name                 = "Transit-Public"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(local.public-block, module.newbits.newbits, 1)]
}


resource "azurerm_network_security_group" "inboundManagement" {
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
  network_security_group_name = azurerm_network_security_group.inboundManagement.name
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
  network_security_group_name = azurerm_network_security_group.inboundManagement.name
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.inboundManagement.id
}

resource "azurerm_network_security_group" "inboundAllowAll" {
  name                = "AllowAll-Subnet"
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
  network_security_group_name = azurerm_network_security_group.inboundAllowAll.name
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.inboundAllowAll.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.inboundAllowAll.id
}

resource "random_string" "randomstring" {
  length      = 6
  min_lower   = 2
  min_numeric = 3
  upper       = false
  special     = false
}

resource "azurerm_storage_account" "this" {
  name                     = join("", list("transitv2vmseries", random_string.randomstring.result))
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_availability_set" "obew" {
  name                        = "${azurerm_resource_group.this.name}-obew"
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  # https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/managed-disks-common-fault-domain-region-list.md
  platform_fault_domain_count = 2
}

resource "azurerm_virtual_network_peering" "panorama-to-transit" {
  name                      = "mgmt-to-transit"
  resource_group_name       = data.terraform_remote_state.panorama.outputs.rg
  virtual_network_name      = data.terraform_remote_state.panorama.outputs.vnet_name
  remote_virtual_network_id = azurerm_virtual_network.this.id
}

resource "azurerm_virtual_network_peering" "transit-to-panorama" {
  name                      = "transit-to-mgmt"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = data.terraform_remote_state.panorama.outputs.vnet_id
  allow_forwarded_traffic   = true
}

output sa_name {
  value = azurerm_storage_account.this.name
}

output sa_key {
  value = azurerm_storage_account.this.primary_access_key
}

output sa_blob {
  value = azurerm_storage_account.this.primary_blob_endpoint
}

output sa_share {
  value = azurerm_storage_share.this.name
}

output mgmt_subnet_id {
  value = azurerm_subnet.management.id
}

output public_subnet_id {
  value = azurerm_subnet.public.id
}

output private_subnet_id {
  value = azurerm_subnet.private.id
}

output mgmt_subnet {
  value = azurerm_subnet.management.address_prefixes[0]
}

output private_subnet {
  value = azurerm_subnet.private.address_prefixes[0]
}

output public_subnet {
  value = azurerm_subnet.public.address_prefixes[0]
}

output sub_rg_name {
  value = module.subscriber-1.rg_name
}

output sub_rg_location {
  value = module.subscriber-1.rg_location
}

output sub_subnet_id {
  value = module.subscriber-1.subnet_id
}

output sub_subnet_cidr {
  value = module.subscriber-1.subnet_cidr
}

output rg_name {
  value = azurerm_resource_group.this.name
}

output rg_location {
  value = azurerm_resource_group.this.location
}

output vnet_name {
  value = azurerm_virtual_network.this.name
}

output public_block {
  value = local.public-block
}

output private_block {
  value = local.private-block
}

output private_gw {
  value = cidrhost(azurerm_subnet.private.address_prefixes[0],1)
}

output baseline_template {
  value = panos_panorama_template.baseline.name
}