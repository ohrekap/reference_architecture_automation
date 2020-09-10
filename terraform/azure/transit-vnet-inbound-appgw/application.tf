module "vmseries-inbound-1" {
    source = "../modules/vmseries/"
    name                    = "${var.deployment_name != "" ? "${var.deployment_name}-vmseries-inbound-1" : "vmseries-inbound-1"}"
    resource_group_name     = data.terraform_remote_state.transit.outputs.rg_name
    resource_group_location = data.terraform_remote_state.transit.outputs.rg_location
    mgmt_subnet_id          = data.terraform_remote_state.transit.outputs.mgmt_subnet_id
    public_subnet_id        = data.terraform_remote_state.transit.outputs.public_subnet_id
    private_subnet_id       = data.terraform_remote_state.transit.outputs.private_subnet_id
    mgmt_ip                 = cidrhost(data.terraform_remote_state.transit.outputs.mgmt_subnet,6)
    public_ip               = cidrhost(data.terraform_remote_state.transit.outputs.public_subnet,6)
    private_ip              = cidrhost(data.terraform_remote_state.transit.outputs.private_subnet,6)
    password                = var.password
    availability_set_id     = azurerm_availability_set.inbound.id
    sa                      = data.terraform_remote_state.transit.outputs.sa_name
    storage_sa              = data.terraform_remote_state.transit.outputs.sa_blob
    access_key              = data.terraform_remote_state.transit.outputs.sa_key
    share                   = data.terraform_remote_state.transit.outputs.sa_share
    directory               = azurerm_storage_share_directory.inbound.name
    #depends_on = [null_resource.inbound]
}

module "vmseries-inbound-2" {
    source = "../modules/vmseries/"
    name                    = "${var.deployment_name != "" ? "${var.deployment_name}-vmseries-inbound-2" : "vmseries-inbound-2"}"
    resource_group_name     = data.terraform_remote_state.transit.outputs.rg_name
    resource_group_location = data.terraform_remote_state.transit.outputs.rg_location
    mgmt_subnet_id          = data.terraform_remote_state.transit.outputs.mgmt_subnet_id
    public_subnet_id        = data.terraform_remote_state.transit.outputs.public_subnet_id
    private_subnet_id       = data.terraform_remote_state.transit.outputs.private_subnet_id
    mgmt_ip                 = cidrhost(data.terraform_remote_state.transit.outputs.mgmt_subnet,7)
    public_ip               = cidrhost(data.terraform_remote_state.transit.outputs.public_subnet,7)
    private_ip              = cidrhost(data.terraform_remote_state.transit.outputs.private_subnet,7)
    password                = var.password
    availability_set_id     = azurerm_availability_set.inbound.id
    sa                      = data.terraform_remote_state.transit.outputs.sa_name
    storage_sa              = data.terraform_remote_state.transit.outputs.sa_blob
    access_key              = data.terraform_remote_state.transit.outputs.sa_key
    share                   = data.terraform_remote_state.transit.outputs.sa_share
    directory               = azurerm_storage_share_directory.inbound.name
    #depends_on = [null_resource.inbound]
}

resource "azurerm_public_ip" "this" {
    name                = "Transit-Public-AppGW"
    domain_name_label   = "transit-public-appgw"
    resource_group_name = data.terraform_remote_state.transit.outputs.rg_name
    location            = data.terraform_remote_state.transit.outputs.rg_location
    sku                 = "Standard"
    allocation_method   = "Static"
}

resource "azurerm_subnet" "this" {
  name                 = "Transit-Public-AppGW"
  resource_group_name  = data.terraform_remote_state.transit.outputs.rg_name
  virtual_network_name = data.terraform_remote_state.transit.outputs.vnet_name 
  address_prefixes     = [cidrsubnet(data.terraform_remote_state.transit.outputs.public_block, module.newbits.newbits, 0)]
}

resource "azurerm_application_gateway" "this" {
  name                = "Transit-AppGW"
  location            = data.terraform_remote_state.transit.outputs.rg_location
  resource_group_name = data.terraform_remote_state.transit.outputs.rg_name
  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
    capacity = 2
  }
  gateway_ip_configuration {
    name = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.this.id
  }
  frontend_port {
    name = "port_80"
    port = 80
  }
  frontend_ip_configuration {
    name                 = "appGwPublicFrontendIp"
    public_ip_address_id = azurerm_public_ip.this.id
  }
  backend_address_pool {
    name = "Firewall-Layer"
    ip_addresses = [module.vmseries-inbound-1.public_interface_ip, module.vmseries-inbound-2.public_interface_ip]
  }
  http_listener {
    name                           = "AppGW-Listen-HTTP-80"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }
  backend_http_settings {
    name                  = "AppGW-Backend-HTTP-80"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }
  /*backend_http_settings {
    name                  = "AppGW-Backend-HTTP-8081"
    cookie_based_affinity = "Disabled"
    port                  = 8081
    protocol              = "Http"
    request_timeout       = 20
  }*/
  
  request_routing_rule {
    name                       = "HTTP-Rule-1"
    rule_type                  = "Basic"
    http_listener_name         = "AppGW-Listen-HTTP-80"
    backend_address_pool_name = "Firewall-Layer"
    backend_http_settings_name = "AppGW-Backend-HTTP-80"
  }

}

resource "azurerm_lb" "this" {
    name                  = "Subscriber1-AppGW-ILB"
    resource_group_name   = data.terraform_remote_state.transit.outputs.sub_rg_name
    location              = data.terraform_remote_state.transit.outputs.sub_rg_location
    sku                   = "Standard"
    frontend_ip_configuration {
        name                          = "LoadBalancerFrontEnd"
        subnet_id                     = data.terraform_remote_state.transit.outputs.sub_subnet_id
        private_ip_address_allocation = "Static"
        private_ip_address = cidrhost(data.terraform_remote_state.transit.outputs.sub_subnet_cidr,101)
    }
}

resource "azurerm_lb_backend_address_pool" "web_pool_1" {
    resource_group_name   = data.terraform_remote_state.transit.outputs.sub_rg_name
    loadbalancer_id       = azurerm_lb.this.id
    name                  = "Web-Pool-1"
}

resource "azurerm_lb_probe" "http" {
    resource_group_name   = data.terraform_remote_state.transit.outputs.sub_rg_name
    loadbalancer_id       = azurerm_lb.this.id
    name                  = "HTTP-Probe"
    port                  = 80
}

resource "azurerm_lb_rule" "AppGW_1" {
    resource_group_name            = data.terraform_remote_state.transit.outputs.sub_rg_name
    loadbalancer_id                = azurerm_lb.this.id
    name                           = "AppGW-1"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "LoadBalancerFrontEnd"
    backend_address_pool_id        = azurerm_lb_backend_address_pool.web_pool_1.id
    probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_network_interface" "web" {
    count                   = 2
    name					          = "web-${count.index}-eth0"
    location                = data.terraform_remote_state.transit.outputs.sub_rg_location
    resource_group_name     = data.terraform_remote_state.transit.outputs.sub_rg_name
    ip_configuration {
      name							            = "ipconfig-mgmt"
      subnet_id						          = data.terraform_remote_state.transit.outputs.sub_subnet_id
      private_ip_address_allocation = "Static"
      private_ip_address            = cidrhost(data.terraform_remote_state.transit.outputs.sub_subnet_cidr,count.index+5)
    }
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
    count                   = 2
    network_interface_id    = azurerm_network_interface.web[count.index].id
    ip_configuration_name   = "ipconfig-mgmt"
    backend_address_pool_id = azurerm_lb_backend_address_pool.web_pool_1.id
}

resource "azurerm_virtual_machine" "web-linux-vm" {
    count                 = 2
    name                  = "web-${count.index}"
    location              = data.terraform_remote_state.transit.outputs.sub_rg_location
    resource_group_name   = data.terraform_remote_state.transit.outputs.sub_rg_name
    network_interface_ids = [azurerm_network_interface.web[count.index].id]
    vm_size               = "Standard_DS1_v2"

    storage_image_reference {
      offer     = "UbuntuServer"
      publisher = "Canonical"
      sku       = "18.04-LTS"
      version   = "latest"
    }

    storage_os_disk {
      name              = "web-${count.index}-os-disk"
      caching           = "ReadWrite"
      create_option     = "FromImage"
      managed_disk_type = "Standard_LRS"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = data.terraform_remote_state.transit.outputs.sa_blob
    }

    os_profile 	{
      computer_name	= "web-${count.index}"
      admin_username	= "refarchadmin"
      admin_password	= var.password
      custom_data     = <<-EOF
                    #!/bin/bash
                    sudo apt-get update
                    sudo apt-get install -y apache2
                    echo "<p> ${count.index} Instance </p>" >> /var/www/html/index.html
                    sudo systemctl enable apache2
                    sudo systemctl start apache2
                    EOF
    }

    delete_os_disk_on_termination    = true
	  delete_data_disks_on_termination = true
}