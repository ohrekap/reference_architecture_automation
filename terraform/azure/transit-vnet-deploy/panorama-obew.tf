resource "panos_panorama_device_group" "obew" {
    name = "Transit-VNet-OBEW"
}

resource "panos_panorama_log_forwarding_profile" "obew" {
    name = "Forward-to-Cortex-Data-Lake"
    device_group = panos_panorama_device_group.obew.name
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

resource "panos_panorama_nat_rule_group" "outbound" {
    device_group = panos_panorama_device_group.obew.name
    rule {
        name = "outbound-internet"
        original_packet {
            source_zones = [panos_panorama_zone.private.name]
            destination_zone = panos_panorama_zone.public.name
            source_addresses = ["any"]
            destination_addresses = ["any"]
        }
        translated_packet {
            source {
                dynamic_ip_and_port {
                    interface_address {
                        interface = panos_panorama_ethernet_interface.public.name
                    }
                }
            }
            destination {
                }
            }
        }
}

resource "panos_panorama_security_rule_group" "outbound" {
    device_group = panos_panorama_device_group.obew.name
    position_keyword = "top"
    rule {
        name = "outbound-interet"
        source_zones = [panos_panorama_zone.private.name]
        source_addresses = ["any"]
        source_users = ["any"]
        hip_profiles = ["any"]
        destination_zones = [panos_panorama_zone.public.name]
        destination_addresses = ["any"]
        applications = ["apt-get","ntp"]
        services = ["application-default"]
        categories = ["any"]
        action = "allow"
        log_setting = panos_panorama_log_forwarding_profile.obew.name
    }
}

resource "panos_panorama_security_rule_group" "east-west-deny" {
    device_group = panos_panorama_device_group.obew.name
    position_keyword = "bottom"
    rule {
        name = "intrazone-deny"
        source_zones = [panos_panorama_zone.private.name]
        source_addresses = ["any"]
        source_users = ["any"]
        hip_profiles = ["any"]
        destination_zones = [panos_panorama_zone.private.name]
        destination_addresses = ["any"]
        applications = ["any"]
        services = ["application-default"]
        categories = ["any"]
        action = "deny"
        log_setting = panos_panorama_log_forwarding_profile.obew.name
    }
}

resource "panos_panorama_template" "baseline" {
    name = "Baseline-VMSeries-Settings"
}

resource "panos_panorama_template" "obew" {
    name = "Transit-2-Zone-OBEW"
}

resource "panos_panorama_template_stack" "obew" {
    name = "Transit-VNet-OBEW"
    templates = [panos_panorama_template.baseline.name, panos_panorama_template.obew.name]
}

resource "panos_panorama_virtual_router" "default" {
    name = "vr-default"
    template = panos_panorama_template.obew.name
}

resource "panos_panorama_ethernet_interface" "public" {
    template = panos_panorama_template.obew.name
    name = "ethernet1/1"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = false
}

resource "panos_panorama_management_profile" "private" {
    name = "MP-Private"
    template = panos_panorama_template.obew.name
    https = true
    permitted_ips = ["168.63.129.16/32"]
}

resource "panos_panorama_ethernet_interface" "private" {
    template = panos_panorama_template.obew.name
    name = "ethernet1/2"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = false
    management_profile = panos_panorama_management_profile.private.name
}

resource "panos_panorama_virtual_router_entry" "public" {
    template = panos_panorama_template.obew.name
    virtual_router = panos_panorama_virtual_router.default.name
    interface = panos_panorama_ethernet_interface.public.name
}

resource "panos_panorama_virtual_router_entry" "private" {
    template = panos_panorama_template.obew.name
    virtual_router = panos_panorama_virtual_router.default.name
    interface = panos_panorama_ethernet_interface.private.name
}


resource "panos_panorama_zone" "public" {
    name = "public"
    template = panos_panorama_template.obew.name
    mode = "layer3"
    interfaces = [panos_panorama_ethernet_interface.public.name]
}

resource "panos_panorama_zone" "private" {
    name = "private"
    template = panos_panorama_template.obew.name
    mode = "layer3"
    interfaces = [panos_panorama_ethernet_interface.private.name]
}

resource "panos_panorama_static_route_ipv4" "private" {
    name = "Net-10.110.0.0_17"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = local.private-block
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(azurerm_subnet.private.address_prefixes[0],1)
}

resource "panos_panorama_static_route_ipv4" "health_probe" {
    name = "Azure-Probe"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = "168.63.129.16/32"
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(azurerm_subnet.private.address_prefixes[0],1)
}

resource "panos_panorama_static_route_ipv4" "default" {
    name = "Default"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = "0.0.0.0/0"
    interface = panos_panorama_ethernet_interface.public.name
    next_hop = cidrhost(azurerm_subnet.public.address_prefixes[0],1)
}

