module "vmseries-obew-1" {
  source = "../modules/vmseries/"
  name                    = "${var.deployment_name != "" ? "${var.deployment_name}-vmseries-obew-1" : "vmseries-obew-1"}"
  resource_group_name     = azurerm_resource_group.this.name
  resource_group_location = azurerm_resource_group.this.location
  mgmt_subnet_id          = azurerm_subnet.management.id
  public_subnet_id        = azurerm_subnet.public.id
  private_subnet_id       = azurerm_subnet.private.id
  mgmt_ip                 = cidrhost(azurerm_subnet.management.address_prefixes[0],4)
  public_ip               = cidrhost(azurerm_subnet.public.address_prefixes[0],4)
  private_ip              = cidrhost(azurerm_subnet.private.address_prefixes[0],4)
  password                = var.password
  availability_set_id     = azurerm_availability_set.obew.id
  sa                      = azurerm_storage_account.this.name
  storage_sa              = azurerm_storage_account.this.primary_blob_endpoint
  access_key              = azurerm_storage_account.this.primary_access_key
  share                   = azurerm_storage_share.this.name
  directory               = azurerm_storage_share_directory.obew.name
  # Stops the VM from starting before the bootstrap files are written
  #depends_on = [null_resource.obew]
}

module "vmseries-obew-2" {
  source = "../modules/vmseries/"
  name                    = "${var.deployment_name != "" ? "${var.deployment_name}-vmseries-obew-2" : "vmseries-obew-2"}"
  resource_group_name     = azurerm_resource_group.this.name
  resource_group_location = azurerm_resource_group.this.location
  mgmt_subnet_id          = azurerm_subnet.management.id
  public_subnet_id        = azurerm_subnet.public.id
  private_subnet_id       = azurerm_subnet.private.id
  mgmt_ip                 = cidrhost(azurerm_subnet.management.address_prefixes[0],5)
  public_ip               = cidrhost(azurerm_subnet.public.address_prefixes[0],5)
  private_ip              = cidrhost(azurerm_subnet.private.address_prefixes[0],5)
  password                = var.password
  availability_set_id     = azurerm_availability_set.obew.id
  sa                      = azurerm_storage_account.this.name
  storage_sa              = azurerm_storage_account.this.primary_blob_endpoint
  access_key              = azurerm_storage_account.this.primary_access_key
  share                   = azurerm_storage_share.this.name
  directory               = azurerm_storage_share_directory.obew.name
  # Stops the VM from starting before the bootstrap files are written
  #depends_on = [null_resource.obew]
}

resource "azurerm_lb" "internal_lb" {
  name                  = "${var.deployment_name != "" ? "${var.deployment_name}-Transit-Internal" : "Transit-Internal"}"
  resource_group_name   = azurerm_resource_group.this.name
  location              = azurerm_resource_group.this.location
  sku                   = "Standard"
  frontend_ip_configuration {
      name                          = "LoadBalancerFrontEnd"
      subnet_id                     = azurerm_subnet.private.id
      private_ip_address_allocation = "Static"
      private_ip_address            = cidrhost(azurerm_subnet.private.address_prefixes[0],21)
  }
}
resource "azurerm_lb_backend_address_pool" "internal_vmseries" {
  resource_group_name   = azurerm_resource_group.this.name
  loadbalancer_id       = azurerm_lb.internal_lb.id
  name                  = "Firewall-Layer-Private"
}

resource "azurerm_network_interface_backend_address_pool_association" "vmseries-obew-1" {
  network_interface_id    = module.vmseries-obew-1.private_interface_id
  ip_configuration_name   = module.vmseries-obew-1.private_interface_config
  backend_address_pool_id = azurerm_lb_backend_address_pool.internal_vmseries.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vmseries-obew-2" {
  network_interface_id    = module.vmseries-obew-2.private_interface_id
  ip_configuration_name   = module.vmseries-obew-2.private_interface_config
  backend_address_pool_id = azurerm_lb_backend_address_pool.internal_vmseries.id
}

resource "azurerm_lb_probe" "https" {
  resource_group_name   = azurerm_resource_group.this.name
  loadbalancer_id       = azurerm_lb.internal_lb.id
  name                  = "HTTPS-Probe"
  port                  = 443
}

resource "azurerm_lb_rule" "ha_ports" {
  resource_group_name            = azurerm_resource_group.this.name
  loadbalancer_id                = azurerm_lb.internal_lb.id
  name                           = "Private-All-Ports"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.internal_vmseries.id
  probe_id                       = azurerm_lb_probe.https.id
}

resource "azurerm_route_table" "management" {
  name                          = "Transit-Management"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  disable_bgp_route_propagation = false
}

resource "azurerm_route_table" "public" {
  name                          = "Transit-Public"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  disable_bgp_route_propagation = false
}

resource "azurerm_route_table" "private" {
  name                          = "Transit-Private"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  disable_bgp_route_propagation = false
}

resource "azurerm_route" "mgmt_blackhole_public" {
  name                = "Blackhole-Public"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.management.name
  address_prefix      = azurerm_subnet.public.address_prefixes[0]
  next_hop_type       = "None"
}

resource "azurerm_route" "mgmt_blackhole_private" {
  name                = "Blackhole-Private"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.management.name
  address_prefix      = local.private-block
  next_hop_type       = "None"
}

resource "azurerm_route" "pub_blackhole_management" {
  name                = "Blackhole-Management"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.public.name
  address_prefix      = azurerm_subnet.management.address_prefixes[0]
  next_hop_type       = "None"
}

resource "azurerm_route" "pub_blackhole_panorama" {
  name                = "Blackhole-Panorama"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.public.name
  address_prefix      = data.terraform_remote_state.panorama.outputs.cidr[0]
  next_hop_type       = "None"
}

resource "azurerm_route" "pub_blackhole_private" {
  name                = "Blackhole-Private"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.public.name
  address_prefix      = local.private-block
  next_hop_type       = "None"
}

resource "azurerm_route" "priv_blackhole_management" {
  name                = "Blackhole-Management"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.private.name
  address_prefix      = azurerm_subnet.management.address_prefixes[0]
  next_hop_type       = "None"
}

resource "azurerm_route" "priv_blackhole_panorama" {
  name                = "Blackhole-Panorama"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.private.name
  address_prefix      = data.terraform_remote_state.panorama.outputs.cidr[0]
  next_hop_type       = "None"
}

resource "azurerm_route" "priv_blackhole_public" {
  name                = "Blackhole-Public"
  resource_group_name = azurerm_resource_group.this.name
  route_table_name    = azurerm_route_table.private.name
  address_prefix      = azurerm_subnet.public.address_prefixes[0]
  next_hop_type       = "None"
}

resource "azurerm_route" "priv_default" {
  name                      = "UDR-default"
  resource_group_name       = azurerm_resource_group.this.name
  route_table_name          = azurerm_route_table.private.name
  address_prefix            = "0.0.0.0/0"
  next_hop_type             = "VirtualAppliance"
  next_hop_in_ip_address    = azurerm_lb.internal_lb.private_ip_address
}

resource "azurerm_subnet_route_table_association" "management" {
  subnet_id      = azurerm_subnet.management.id
  route_table_id = azurerm_route_table.management.id
}

resource "azurerm_subnet_route_table_association" "public" {
  subnet_id      = azurerm_subnet.public.id
  route_table_id = azurerm_route_table.public.id
}

resource "azurerm_subnet_route_table_association" "private" {
  subnet_id      = azurerm_subnet.private.id
  route_table_id = azurerm_route_table.private.id
}