variable name {}
variable resource_group_name {}
variable resource_group_location {}
variable mgmt_subnet_id {}
variable public_subnet_id {}
variable private_subnet_id {}
variable mgmt_ip {}
variable public_ip {}
variable private_ip {}
variable password {}
variable availability_set_id {}
variable storage_sa {}
variable sa {}
variable access_key {}
variable share {}
variable directory {}


locals {
    virtualMachineSize  = "Standard_D3_v2"
    vmseriesVersion     = "9.1.3"
    userName            = "refarchadmin"
}

resource "azurerm_public_ip" "this" {
    name                = var.name
    domain_name_label   = var.name
    resource_group_name = var.resource_group_name
    location            = var.resource_group_location
    sku                 = "Standard"
    allocation_method   = "Static"
}

resource "azurerm_public_ip" "public" {
    name                = "${var.name}-outbound"
    domain_name_label   = "${var.name}-outbound"
    resource_group_name = var.resource_group_name
    location            = var.resource_group_location
    sku                 = "Standard"
    allocation_method   = "Static"
}

resource "azurerm_network_interface" "mgmt" {
	name					= "${azurerm_public_ip.this.name}-eth0"
	location                = var.resource_group_location
	resource_group_name     = var.resource_group_name
	ip_configuration {
		name							= "ipconfig-mgmt"
		subnet_id						= var.mgmt_subnet_id
		private_ip_address_allocation 	= "Static"
        private_ip_address              = var.mgmt_ip
		public_ip_address_id            = azurerm_public_ip.this.id
	}
}

resource "azurerm_network_interface" "public" {
	name					= "${azurerm_public_ip.this.name}-eth1"
	location                = var.resource_group_location
	resource_group_name     = var.resource_group_name
	enable_ip_forwarding	= true
	ip_configuration {
		name							= "ipconfig-public"
		subnet_id						= var.public_subnet_id
		private_ip_address_allocation 	= "Static"
        private_ip_address              = var.public_ip
		public_ip_address_id            = azurerm_public_ip.public.id
	}
}

resource "azurerm_network_interface" "private" {
	name					= "${azurerm_public_ip.this.name}-eth2"
	location                = var.resource_group_location
	resource_group_name     = var.resource_group_name
	enable_ip_forwarding	= true
	ip_configuration {
		name							= "ipconfig-private"
		subnet_id						= var.private_subnet_id
		private_ip_address_allocation 	= "Static"
        private_ip_address              = var.private_ip
	}
}

resource "azurerm_virtual_machine" "this" {
	name					= azurerm_public_ip.this.name
	location				= var.resource_group_location
	resource_group_name	    = var.resource_group_name
	network_interface_ids   = [ azurerm_network_interface.mgmt.id,
		azurerm_network_interface.public.id,
		azurerm_network_interface.private.id ]

	primary_network_interface_id		= azurerm_network_interface.mgmt.id
	vm_size								= local.virtualMachineSize
    availability_set_id                 = var.availability_set_id

  plan {
        name        = "byol"
        publisher   = "paloaltonetworks"
        product     = "vmseries-flex"
    }

	storage_image_reference	{
		publisher 	= "paloaltonetworks"
		offer		= "vmseries-flex"
		sku			= "byol"
		version		= local.vmseriesVersion
	}

	storage_os_disk {
	    name              = "${azurerm_public_ip.this.name}-osdisk"
		caching           = "ReadWrite"
		create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
	}

	delete_os_disk_on_termination    = true
	delete_data_disks_on_termination = true

	os_profile 	{
		computer_name	= azurerm_public_ip.this.name
		admin_username	= local.userName
		admin_password	= var.password
		#custom_data     = "storage-account=${var.sa},access-key=${var.access_key},file-share=${var.share},share-directory=${var.directory}"
        custom_data     = join(",",
                            [
                                "storage-account=${var.sa}",
                                "access-key=${var.access_key}",
                                "file-share=${var.share}",
                                "share-directory=${var.directory}"
                            ],)
	}

	os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = var.storage_sa
    }
}

output private_interface_id {
    value = azurerm_network_interface.private.id
}

output private_interface_config {
    value = "ipconfig-private"
}

output public_interface_id {
    value = azurerm_network_interface.public.id
}

output public_interface_config {
    value = "ipconfig-public"
}

output public_interface_ip {
    value = azurerm_network_interface.public.private_ip_address
}