variable resource_group_name {}

variable resource_group_location {}

variable subnet_id {}

variable subnet_prefix {}

variable availability_set_id {}

variable password {}

variable diag_sa {}

variable enable_ha {}

variable deployment_name {}

locals {
    virtualMachineSize  = "Standard_D3_v2"
    panoramaVersion     = "9.1.2"
    primaryName         = "${var.deployment_name != "" ? "${var.deployment_name}-panorama-primary" : "panorama-primary"}"
    #primaryName        = "panorama-primary"
    #secondaryName      = "panorama-secondary"
    secondaryName       = "${var.deployment_name != "" ? "${var.deployment_name}-panorama-secondary" : "panorama-secondary"}"
    userName            = "refarchadmin"
}


resource "azurerm_public_ip" "primary" {
    name                = local.primaryName
    domain_name_label   = local.primaryName
    resource_group_name = var.resource_group_name
    location            = var.resource_group_location
    sku                 = "Standard"
    allocation_method   = "Static"
}

resource "azurerm_network_interface" "primary" {
	name					= "${azurerm_public_ip.primary.name}-eth0"
	location                = var.resource_group_location
	resource_group_name     = var.resource_group_name
	ip_configuration {
		name							= "ipconfig-mgmt"
		subnet_id						= var.subnet_id
		private_ip_address_allocation 	= "Static"
        private_ip_address              = cidrhost(var.subnet_prefix,4)
		public_ip_address_id            = azurerm_public_ip.primary.id
	}
}

resource "azurerm_virtual_machine" "primary" {
	name                            = azurerm_public_ip.primary.name
	location						= var.resource_group_location
	resource_group_name             = var.resource_group_name
	network_interface_ids           = [ azurerm_network_interface.primary.id ]
	primary_network_interface_id    = azurerm_network_interface.primary.id
	vm_size							= local.virtualMachineSize
    availability_set_id             = var.availability_set_id


    plan {
        name      = "byol"
        publisher = "paloaltonetworks"
        product   = "panorama"
    }

	storage_image_reference	{
		publisher 	= "paloaltonetworks"
		offer		= "panorama"
		sku			= "byol"
		version		= local.panoramaVersion
	}

	storage_os_disk {
	    name             = "${azurerm_public_ip.primary.name}-osdisk"
		caching           = "ReadWrite"
		create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
	}

	delete_os_disk_on_termination    = true
	delete_data_disks_on_termination = true

	os_profile 	{
		computer_name	= azurerm_public_ip.primary.name
		admin_username	= local.userName
		admin_password	= var.password
	}

	os_profile_linux_config {
        disable_password_authentication = false
    }
  
    boot_diagnostics {
        enabled     = "true"
        storage_uri = var.diag_sa
    }
}

resource "azurerm_public_ip" "secondary" {
    count = var.enable_ha ? 1 : 0
    name                = local.secondaryName
    domain_name_label   = local.secondaryName
    resource_group_name = var.resource_group_name
    location            = var.resource_group_location
    sku                 = "Standard"
    allocation_method   = "Static"
}

resource "azurerm_network_interface" "secondary" {
	count = var.enable_ha ? 1 : 0
    name				= "${azurerm_public_ip.secondary[0].name}-eth0"
	location            = var.resource_group_location
	resource_group_name = var.resource_group_name
	ip_configuration {
		name							= "ipconfig-mgmt"
		subnet_id						= var.subnet_id
		private_ip_address_allocation 	= "Static"
        private_ip_address              = cidrhost(var.subnet_prefix,5)
		public_ip_address_id            = azurerm_public_ip.secondary[0].id
	}
}

resource "azurerm_virtual_machine" "secondary" {
    count = var.enable_ha ? 1 : 0
	name                            = azurerm_public_ip.secondary[0].name
	location						= var.resource_group_location
	resource_group_name             = var.resource_group_name
	network_interface_ids           = [ azurerm_network_interface.secondary[0].id ]
	primary_network_interface_id    = azurerm_network_interface.secondary[0].id
	vm_size							= local.virtualMachineSize
    availability_set_id             = var.availability_set_id


    plan {
        name      = "byol"
        publisher = "paloaltonetworks"
        product   = "panorama"
    }

	storage_image_reference	{
		publisher 	= "paloaltonetworks"
		offer		= "panorama"
		sku			= "byol"
		version		= local.panoramaVersion
	}

	storage_os_disk {
	    name             = "${azurerm_public_ip.secondary[0].name}-osdisk"
		caching           = "ReadWrite"
		create_option     = "FromImage"
        managed_disk_type = "StandardSSD_LRS"
	}

	delete_os_disk_on_termination    = true
	delete_data_disks_on_termination = true

	os_profile 	{
		computer_name	= azurerm_public_ip.secondary[0].name
		admin_username	= local.userName
		admin_password	= var.password
	}

	os_profile_linux_config {
        disable_password_authentication = false
    }
  
    boot_diagnostics {
        enabled     = "true"
        storage_uri = var.diag_sa
    }
}

output "primary_ip" {
  value = azurerm_public_ip.primary.fqdn
}

# I have to use the join because if I tried to access [0] and it isn't created then it errors out. Since there is only one management
# interface then the output will either be nothing or the FQDN of the second Panorama instance. If conditional output ever happen this 
# should be adjusted.
output "secondary_ip" {
    value = join(",", azurerm_public_ip.secondary[*].fqdn)
    description = "The public IP of the secondary Panorama"
}

output "primary_private_ip" {
    value = azurerm_network_interface.primary.private_ip_address
    description = "The private IP of the primary Panorama"
}

# I have to use the join because if I tried to access [0] and it isn't created then it errors out. Since there is only one management
# interface then the output will either be nothing or the IP of the second Panorama instance. If conditional output ever happen this 
# should be adjusted.
output "secondary_private_ip" {
    value = join(",", azurerm_network_interface.secondary[*].private_ip_address)
    description = "The public IP of the secondary Panorama"
}