resource "panos_panorama_device_group" "inbound" {
    name = "Transit-VNet-Inbound"
}

resource "panos_panorama_log_forwarding_profile" "inbound" {
    name = "Forward-to-Cortex-Data-Lake"
    device_group = panos_panorama_device_group.inbound.name
    enhanced_logging = true
    match_list {
        name = "traffic-enhanced-app-logging"
        log_type = "traffic"
        send_to_panorama = true
    }
    match_list {
        name = "threat-enhanced-app-logging"
        log_type = "threat"
        send_to_panorama = true
    }
    match_list {
        name = "wildfire-enhanced-app-logging"
        log_type = "wildfire"
        send_to_panorama = true
    }
    match_list {
        name = "url-enhanced-app-logging"
        log_type = "url"
        send_to_panorama = true
    }
    match_list {
        name = "data-enhanced-app-logging"
        log_type = "data"
        send_to_panorama = true
    }
    match_list {
        name = "tunnel-enhanced-app-logging"
        log_type = "tunnel"
        send_to_panorama = true
    }
    match_list {
        name = "auth-enhanced-app-logging"
        log_type = "auth"
        send_to_panorama = true
    }

}

resource "panos_panorama_template" "inbound" {
    name = "Transit-2-Zone-Inbound"
}

resource "panos_panorama_template_stack" "inbound" {
    name = "Transit-VNet-Inbound"
    templates = [data.terraform_remote_state.transit.outputs.baseline_template, panos_panorama_template.inbound.name]
}

resource "panos_panorama_virtual_router" "inbound-default" {
    name = "vr-default"
    template = panos_panorama_template.inbound.name
}

resource "panos_panorama_management_profile" "inbound-public" {
    name = "MP-Public"
    template = panos_panorama_template.inbound.name
    https = true
    permitted_ips = ["168.63.129.16/32"]
}

resource "panos_panorama_ethernet_interface" "inbound-public" {
    template = panos_panorama_template.inbound.name
    name = "ethernet1/1"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = false
    management_profile = panos_panorama_management_profile.inbound-public.name
}


resource "panos_panorama_ethernet_interface" "inbound-private" {
    template = panos_panorama_template.inbound.name
    name = "ethernet1/2"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = false
}

resource "panos_panorama_virtual_router_entry" "inbound-public" {
    template = panos_panorama_template.inbound.name
    virtual_router = panos_panorama_virtual_router.inbound-default.name
    interface = panos_panorama_ethernet_interface.inbound-public.name
}

resource "panos_panorama_virtual_router_entry" "inbound-private" {
    template = panos_panorama_template.inbound.name
    virtual_router = panos_panorama_virtual_router.inbound-default.name
    interface = panos_panorama_ethernet_interface.inbound-private.name
}


resource "panos_panorama_zone" "inbound-public" {
    name = "public"
    template = panos_panorama_template.inbound.name
    mode = "layer3"
    interfaces = [panos_panorama_ethernet_interface.inbound-public.name]
}

resource "panos_panorama_zone" "inbound-private" {
    name = "private"
    template = panos_panorama_template.inbound.name
    mode = "layer3"
    interfaces = [panos_panorama_ethernet_interface.inbound-private.name]
}

resource "panos_panorama_static_route_ipv4" "inbound-private" {
    name = "Net-10.110.0.0_17"
    virtual_router = panos_panorama_virtual_router.inbound-default.name
    template = panos_panorama_template.inbound.name
    destination = data.terraform_remote_state.transit.outputs.private_block
    interface = panos_panorama_ethernet_interface.inbound-private.name
    next_hop = data.terraform_remote_state.transit.outputs.private_gw
}

resource "panos_panorama_static_route_ipv4" "inbound-subscriber" {
    name = "Net-Subscriber"
    virtual_router = panos_panorama_virtual_router.inbound-default.name
    template = panos_panorama_template.inbound.name
    destination = data.terraform_remote_state.transit.outputs.sub_subnet_cidr
    interface = panos_panorama_ethernet_interface.inbound-private.name
    next_hop = data.terraform_remote_state.transit.outputs.private_gw
}

resource "panos_panorama_static_route_ipv4" "default" {
    name = "Default"
    virtual_router = panos_panorama_virtual_router.inbound-default.name
    template = panos_panorama_template.inbound.name
    destination = "0.0.0.0/0"
    interface = panos_panorama_ethernet_interface.inbound-public.name
    next_hop = cidrhost(data.terraform_remote_state.transit.outputs.public_subnet,1)
}

resource "panos_panorama_address_object" "vmseries-1" {
    name = "inbound-vmseries-1-public"
    value = module.vmseries-inbound-1.public_interface_ip
    device_group = panos_panorama_device_group.inbound.name
}

resource "panos_panorama_address_object" "vmseries-2" {
    name = "inbound-vmseries-2-public"
    value = module.vmseries-inbound-2.public_interface_ip
    device_group = panos_panorama_device_group.inbound.name
}

resource "panos_panorama_address_object" "AppGW-Subnet" {
    name = "AppGW-Subnet"
    value = azurerm_subnet.this.address_prefix
    device_group = panos_panorama_device_group.inbound.name
}

resource "panos_panorama_address_object" "AppGW-Internal-LB" {
    name = "AppGW-Internal-LB"
    value = azurerm_lb.this.private_ip_address
    device_group = panos_panorama_device_group.inbound.name
}

resource "panos_panorama_nat_rule_group" "inbound" {
    device_group = panos_panorama_device_group.inbound.name
    rule {
        name = "inbound-example-application"
        original_packet {
            source_zones          = [panos_panorama_zone.inbound-public.name]
            destination_zone      = panos_panorama_zone.inbound-public.name
            destination_interface = panos_panorama_ethernet_interface.inbound-public.name
            service               = "service-http"
            source_addresses      = ["any"]
            destination_addresses = ["any"]
        }
        translated_packet {
            source {
                dynamic_ip_and_port {
                    interface_address {
                        interface = panos_panorama_ethernet_interface.inbound-private.name
                    }
                }
            }
            destination {
                dynamic_translation {
                    address = panos_panorama_address_object.AppGW-Internal-LB.name
                }
            }
        }
    }
}

resource "panos_panorama_security_rule_group" "inbound" {
    device_group     = panos_panorama_device_group.inbound.name 
    position_keyword = "top"
    rule {
        name                  = "inbound-example-application"
        source_zones          = [panos_panorama_zone.inbound-public.name] 
        source_addresses      = ["any"]
        source_users          = ["any"]
        hip_profiles          = ["any"]
        destination_zones     = [panos_panorama_zone.inbound-private.name] 
        destination_addresses = ["any"]
        applications          = ["web-browsing"]
        services              = ["application-default"]
        categories            = ["any"]
        action                = "allow"
        log_setting           = panos_panorama_log_forwarding_profile.inbound.name 
    }
}
