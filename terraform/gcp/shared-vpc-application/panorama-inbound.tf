resource "panos_panorama_device_group" "inbound" {
    name = "VMSeries-Inbound-Group"
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

resource "panos_panorama_nat_rule_group" "inbound" {
    device_group = panos_panorama_device_group.inbound.name
    rule {
        name = "inbound-web-application"
        original_packet {
            source_zones = [panos_panorama_zone.public.name]
            destination_zone = panos_panorama_zone.public.name
            destination_interface = panos_panorama_ethernet_interface.public.name
            service               = "service-http"
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
                dynamic_translation {
                    address = google_compute_forwarding_rule.default.ip_address
                }
                }
            }
        }
}

resource "panos_panorama_security_rule_group" "inbound" {
    device_group = panos_panorama_device_group.inbound.name
    position_keyword = "top"
    rule {
        name = "inbound-web-application"
        source_zones = [panos_panorama_zone.public.name]
        source_addresses = ["any"]
        source_users = ["any"]
        hip_profiles = ["any"]
        destination_zones = [panos_panorama_zone.private.name]
        destination_addresses = ["any"] #
        applications = ["web-browsing"]
        services = ["application-default"]
        categories = ["any"]
        action = "allow"
        log_setting = panos_panorama_log_forwarding_profile.inbound.name
    }
}

resource "panos_panorama_security_rule_group" "east-west-deny" {
    device_group = panos_panorama_device_group.inbound.name
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
        log_setting = panos_panorama_log_forwarding_profile.inbound.name
    }
}

resource "panos_panorama_template" "inbound" {
    name = "Inbound-Group-Network-Settings"
}

resource "panos_panorama_template_stack" "inbound" {
    name = "Inbound-Group-Stack"
    templates = [panos_panorama_template.inbound.name] #baseline
}

resource "panos_panorama_virtual_router" "default" {
    name = "vr-default"
    template = panos_panorama_template.inbound.name
}

resource "panos_panorama_ethernet_interface" "private" {
    template = panos_panorama_template.inbound.name
    name = "ethernet1/2"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = false
}

resource "panos_panorama_ethernet_interface" "public" {
    template = panos_panorama_template.inbound.name
    name = "ethernet1/1"
    mode = "layer3"
    enable_dhcp = true
    create_dhcp_default_route = true
}

resource "panos_panorama_virtual_router_entry" "public" {
    template = panos_panorama_template.inbound.name
    virtual_router = panos_panorama_virtual_router.default.name
    interface = panos_panorama_ethernet_interface.public.name
}

resource "panos_panorama_virtual_router_entry" "private" {
    template = panos_panorama_template.inbound.name
    virtual_router = panos_panorama_virtual_router.default.name
    interface = panos_panorama_ethernet_interface.private.name
}

resource "panos_panorama_zone" "public" {
    name = "public"
    template = panos_panorama_template.inbound.name
    mode = "layer3"
    interfaces = [panos_panorama_ethernet_interface.public.name]
}

resource "panos_panorama_zone" "private" {
    name = "private"
    template = panos_panorama_template.inbound.name
    mode = "layer3"
    interfaces = [panos_panorama_ethernet_interface.private.name]
}

resource "panos_panorama_static_route_ipv4" "private" {
    name = "Web Subnet"
    virtual_router = panos_panorama_virtual_router.default.name
    template = panos_panorama_template.inbound.name
    destination = data.terraform_remote_state.shared-vpc.outputs.web_subnet_cidr
    interface = panos_panorama_ethernet_interface.private.name
    next_hop = cidrhost(data.terraform_remote_state.shared-vpc.outputs.private_subnet_cidr,1) 
}