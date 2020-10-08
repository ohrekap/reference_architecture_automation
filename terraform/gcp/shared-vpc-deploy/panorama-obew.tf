resource "panos_panorama_device_group" "obew" {
    name = "VMSeries-OBEW-Group"
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

resource "panos_panorama_nat_rule_group" "east-west" {
    device_group = panos_panorama_device_group.obew.name
    rule {
        name = "east-west"
        original_packet {
            source_zones = [panos_panorama_zone.private.name]
            destination_zone = panos_panorama_zone.private.name
            source_addresses = ["any"]
            destination_addresses = ["any"]
        }
        translated_packet {
            source {
                dynamic_ip_and_port {
                    interface_address {
                        interface = panos_panorama_ethernet_interface.private.name
                    }
                }
            }
            destination {
                }
            }
        }
}

resource "panos_panorama_nat_rule_group" "health_check" {
    device_group = panos_panorama_device_group.obew.name
    rule {
        name = "ilb-health-check"
        original_packet {
            source_zones = [panos_panorama_zone.private.name]
            destination_zone = panos_panorama_zone.private.name
            source_addresses = ["35.191.0.0/16", "130.211.0.0/22"]
            destination_addresses = ["any"]
        }
        translated_packet {
            source {
            }
            destination {
                dynamic_translation {
                    address = panos_panorama_loopback_interface.loopback.static_ips[0]
                }
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
        applications = ["apt-get","ntp", "yum"]
        services = ["application-default"]
        categories = ["any"]
        action = "allow"
        log_setting = panos_panorama_log_forwarding_profile.obew.name
    }
}

resource "panos_panorama_security_rule_group" "health-check" {
    device_group = panos_panorama_device_group.obew.name
    position_keyword = "top"
    rule {
        name = "ilb-health-check"
        source_zones = [panos_panorama_zone.private.name]
        source_addresses = ["35.191.0.0/16", "130.211.0.0/22"]
        source_users = ["any"]
        hip_profiles = ["any"]
        destination_zones = [panos_panorama_zone.private.name]
        destination_addresses = ["any"]
        applications = ["ssh"]
        services = ["application-default"]
        categories = ["any"]
        action = "allow"
        log_setting = panos_panorama_log_forwarding_profile.obew.name
    }
}

resource "panos_panorama_security_rule_group" "web-to-db" {
    device_group = panos_panorama_device_group.obew.name
    position_keyword = "top"
    rule {
        name = "web-to-db"
        source_zones = [panos_panorama_zone.private.name]
        source_addresses = [module.web-vpc.subnets_ips[0]]
        source_users = ["any"]
        hip_profiles = ["any"]
        destination_zones = [panos_panorama_zone.private.name]
        destination_addresses = [module.db-vpc.subnets_ips[0]]
        applications = ["ssh"]
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
    name = "OBEW-Group-Network-Settings"
}

resource "panos_panorama_template_stack" "obew" {
    name = "OBEW-Group-Stack"
    templates = [panos_panorama_template.baseline.name, panos_panorama_template.obew.name]
}

resource "panos_panorama_virtual_router" "default" {
    name = "vr-default"
    template = panos_panorama_template.obew.name
}

resource "panos_panorama_ethernet_interface" "private" {
    template = panos_panorama_template.obew.name
    name = "ethernet1/1"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = false
}

resource "panos_panorama_loopback_interface" "loopback" {
    name = "loopback.1"
    template = panos_panorama_template.obew.name
    static_ips = ["100.64.0.1"]
    management_profile = panos_panorama_management_profile.loopback.name
}

resource "panos_panorama_management_profile" "loopback" {
    name = "Loopback SSH Only"
    template = panos_panorama_template.obew.name
    ssh = true
    permitted_ips = ["35.191.0.0/16", "130.211.0.0/22"]
}

resource "panos_panorama_ethernet_interface" "public" {
    template = panos_panorama_template.obew.name
    name = "ethernet1/2"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = true
    #management_profile = panos_panorama_management_profile.private.name
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

resource "panos_panorama_virtual_router_entry" "loopback" {
    template = panos_panorama_template.obew.name
    virtual_router = panos_panorama_virtual_router.default.name
    interface = panos_panorama_loopback_interface.loopback.name
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
    interfaces = [panos_panorama_ethernet_interface.private.name, panos_panorama_loopback_interface.loopback.name]
}

resource "panos_panorama_static_route_ipv4" "private" {
    name = "Web Subnet"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = module.web-vpc.subnets_ips[0]
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(module.private-vpc.subnets_ips[0],1) 
}

resource "panos_panorama_static_route_ipv4" "db" {
    name = "DB Subnet"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = module.db-vpc.subnets_ips[0]
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(module.private-vpc.subnets_ips[0],1) 
}

resource "panos_panorama_static_route_ipv4" "hc130" {
    name = "ILB Health Check 130"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = "130.211.0.0/22"
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(module.private-vpc.subnets_ips[0],1) 
}

resource "panos_panorama_static_route_ipv4" "hc35" {
    name = "ILB Health Check 35"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.obew.name
    destination = "35.191.0.0/16"
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(module.private-vpc.subnets_ips[0],1) 
}
