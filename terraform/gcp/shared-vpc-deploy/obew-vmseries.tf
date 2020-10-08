module "vmseries-obew-1" {
    source = "../modules/vmseries/"
    name                = "vmseries-3"
    project             = module.host-project.project_id
    gcp_region          = var.gcp_region
    ra_key              = var.ra_key
    availability_zone   = local.availability_zones[0]
    public_subnet       = module.public-vpc.subnets_self_links[0]
    public_ip           = cidrhost(module.public-vpc.subnets_ips[0],6)
    private_subnet      = module.private-vpc.subnets_self_links[0]
    private_ip          = cidrhost(module.private-vpc.subnets_ips[0],6)
    mgmt_subnet         = module.management-vpc.subnets_self_links[0]
    mgmt_ip             = cidrhost(module.management-vpc.subnets_ips[0],6)
    bootstrap_bucket    = google_storage_bucket.vmseries-obew.name
}

module "vmseries-obew-2" {
    source = "../modules/vmseries/"
    name                = "vmseries-4"
    project             = module.host-project.project_id
    gcp_region          = var.gcp_region
    ra_key              = var.ra_key
    availability_zone   = local.availability_zones[1]
    public_subnet       = module.public-vpc.subnets_self_links[0]
    public_ip           = cidrhost(module.public-vpc.subnets_ips[0],7)
    private_subnet      = module.private-vpc.subnets_self_links[0]
    private_ip          = cidrhost(module.private-vpc.subnets_ips[0],7)
    mgmt_subnet         = module.management-vpc.subnets_self_links[0]
    mgmt_ip             = cidrhost(module.management-vpc.subnets_ips[0],7)
    bootstrap_bucket    = google_storage_bucket.vmseries-obew.name
}

resource "google_compute_firewall" "vmseries-mgmt" {
  name    = "vmseries-mgmt"
  project = module.host-project.project_id
  network = module.management-vpc.network_self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }

  source_ranges = [var.onprem_IPaddress]
  target_tags   = ["vm-series"]
}

resource "google_compute_firewall" "vmseries-panorama" {
  name    = "vmseries-panorama"
  project  = module.host-project.project_id
  network = module.management-vpc.network_self_link

  allow {
    protocol = "all"
  }

  source_ranges = ["10.255.0.0/16"]
}

resource "google_compute_firewall" "vmseries-private" {
  name    = "vmseries-private"
  project  = module.host-project.project_id
  network = module.private-vpc.network_self_link

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vm-series"]
}

resource "google_compute_firewall" "web-inbound" {
  name    = "web-inbound"
  project  = module.host-project.project_id
  network = module.web-vpc.network_self_link

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "db-inbound" {
  name    = "db-inbound"
  project  = module.host-project.project_id
  network = module.db-vpc.network_self_link

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_health_check" "ilbnh-health-check" {
    name = "obew-vmseries-health-check"
    project  = module.host-project.project_id
    timeout_sec        = 20
    check_interval_sec = 20

    tcp_health_check {
        port = "22"
    }
}

resource "google_compute_region_backend_service" "obew-backend" {
    name             = "obew-tcp-lb"
    project          = module.host-project.project_id
    region           = var.gcp_region
    protocol         = "TCP"
    network          = module.private-vpc.network_self_link
    health_checks    = [google_compute_health_check.ilbnh-health-check.id]
    session_affinity = "CLIENT_IP"

    backend {
        group = module.vmseries-obew-1.instance_group
    }

    backend {
        group = module.vmseries-obew-2.instance_group
    }
}

resource "google_compute_forwarding_rule" "default" {
    name   = "obew-tcp-lb-frontend"
    region = var.gcp_region
    project          = module.host-project.project_id
    load_balancing_scheme = "INTERNAL"
    backend_service       = google_compute_region_backend_service.obew-backend.id
    all_ports             = true
    network               = module.private-vpc.network_self_link
    subnetwork            = module.private-vpc.subnets_self_links[0]
}

resource "google_compute_route" "route-ilb" {
    name         = "private-obew-default"
    project          = module.host-project.project_id
    dest_range   = "0.0.0.0/0"
    network      = module.private-vpc.network_self_link
    next_hop_ilb = google_compute_forwarding_rule.default.id
    priority     = 100
}