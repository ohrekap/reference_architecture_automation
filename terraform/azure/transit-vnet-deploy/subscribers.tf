module "subscriber-1" {
    source           = "../modules/subscriber/"
    name             = "${var.deployment_name != "" ? "${var.deployment_name}-subscriber-1" : "subscriber-1"}"
    cidr_block       = "10.112.0.0/16"
    azure_region     = var.azure_region
    lb_ip            = azurerm_lb.internal_lb.private_ip_address
    remote_vnet_name = azurerm_virtual_network.this.name
    remote_vnet_id   = azurerm_virtual_network.this.id
    remote_rg_name   = azurerm_resource_group.this.name
    management_prefix = azurerm_subnet.management.address_prefixes[0]
    public_prefix    = azurerm_subnet.public.address_prefixes[0]
    public_rt        = azurerm_route_table.public.name
    management_rt    = azurerm_route_table.management.name
}

resource "panos_panorama_static_route_ipv4" "sub_1" {
    name = "Net-10.112.0.0_16"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = module.subscriber-1.subnet_cidr
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(azurerm_subnet.private.address_prefixes[0],1)
}


module "subscriber-2" {
    source           = "../modules/subscriber/"
    name             = "${var.deployment_name != "" ? "${var.deployment_name}-subscriber-2" : "subscriber-2"}"
    cidr_block       = "10.113.0.0/16"
    azure_region     = var.azure_region
    lb_ip            = azurerm_lb.internal_lb.private_ip_address
    remote_vnet_name = azurerm_virtual_network.this.name
    remote_vnet_id   = azurerm_virtual_network.this.id
    remote_rg_name   = azurerm_resource_group.this.name
    management_prefix = azurerm_subnet.management.address_prefixes[0]
    public_prefix    = azurerm_subnet.public.address_prefixes[0]
    public_rt        = azurerm_route_table.public.name
    management_rt    = azurerm_route_table.management.name
}

resource "panos_panorama_static_route_ipv4" "sub_2" {
    name = "Net-10.113.0.0_16"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = module.subscriber-2.subnet_cidr
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(azurerm_subnet.private.address_prefixes[0],1)
}