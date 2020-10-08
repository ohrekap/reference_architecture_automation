module "vmseries-inbound-1" {
    source = "../modules/vmseries-inbound/"
    name                = "vmseries-1"
    project             = data.terraform_remote_state.shared-vpc.outputs.host_project
    gcp_region          = var.gcp_region
    ra_key              = var.ra_key
    availability_zone   = local.availability_zones[0]
    public_subnet       = data.terraform_remote_state.shared-vpc.outputs.public_subnet
    public_ip           = cidrhost(data.terraform_remote_state.shared-vpc.outputs.public_subnet_cidr,4)
    private_subnet      = data.terraform_remote_state.shared-vpc.outputs.private_subnet
    private_ip          = cidrhost(data.terraform_remote_state.shared-vpc.outputs.private_subnet_cidr,4)
    mgmt_subnet         = data.terraform_remote_state.shared-vpc.outputs.mgmt_subnet
    mgmt_ip             = cidrhost(data.terraform_remote_state.shared-vpc.outputs.mgmt_subnet_cidr,4)
    bootstrap_bucket    = google_storage_bucket.vmseries-inbound.name
}

module "vmseries-inbound-2" {
    source = "../modules/vmseries-inbound/"
    name                = "vmseries-2"
    project             = data.terraform_remote_state.shared-vpc.outputs.host_project
    gcp_region          = var.gcp_region
    ra_key              = var.ra_key
    availability_zone   = local.availability_zones[1]
    public_subnet       = data.terraform_remote_state.shared-vpc.outputs.public_subnet
    public_ip           = cidrhost(data.terraform_remote_state.shared-vpc.outputs.public_subnet_cidr,5)
    private_subnet      = data.terraform_remote_state.shared-vpc.outputs.private_subnet
    private_ip          = cidrhost(data.terraform_remote_state.shared-vpc.outputs.private_subnet_cidr,5)
    mgmt_subnet         = data.terraform_remote_state.shared-vpc.outputs.mgmt_subnet
    mgmt_ip             = cidrhost(data.terraform_remote_state.shared-vpc.outputs.mgmt_subnet_cidr,5)
    bootstrap_bucket    = google_storage_bucket.vmseries-inbound.name
}

resource "google_compute_instance_group_named_port" "http-1" {
  group = module.vmseries-inbound-1.instance_group
  project  = data.terraform_remote_state.shared-vpc.outputs.host_project
  name = "http"
  port = 80
}

resource "google_compute_instance_group_named_port" "http-2" {
  group = module.vmseries-inbound-2.instance_group
  project  = data.terraform_remote_state.shared-vpc.outputs.host_project
  name = "http"
  port = 80
}

resource "google_compute_firewall" "vmseries-private" {
  name    = "vmseries-public-inbound"
  project = data.terraform_remote_state.shared-vpc.outputs.host_project
  network = data.terraform_remote_state.shared-vpc.outputs.public_subnet

  allow {
    protocol  = "tcp"
    ports     = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vm-series-inbound"]
}

resource "google_compute_health_check" "inbound-http-health-check" {
    name = "inbound-http-health-check"
    project  = data.terraform_remote_state.shared-vpc.outputs.host_project
    timeout_sec        = 2
    check_interval_sec = 2

    http_health_check {
        port = "80"
    }
}

resource "google_compute_backend_service" "default" {
  name                  = "web-application-backend"
  project          = data.terraform_remote_state.shared-vpc.outputs.host_project
  port_name             = "http"
  protocol              = "HTTP"
  timeout_sec           = 10

    backend {
        group = module.vmseries-inbound-1.instance_group
    }

    backend {
        group = module.vmseries-inbound-2.instance_group
    }

  health_checks = [google_compute_health_check.inbound-http-health-check.id]
}

resource "google_compute_url_map" "default" {
  name            = "url-map"
  project          = data.terraform_remote_state.shared-vpc.outputs.host_project
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_http_proxy" "default" {
  name        = "target-proxy"
  project          = data.terraform_remote_state.shared-vpc.outputs.host_project
  url_map     = google_compute_url_map.default.id
}

# I am not using a static external IP to keep the IP addresses under 8 (which is a default limit)
/*resource "google_compute_address" "lb" {
    name    = "inbound-http-lb"
    project = data.terraform_remote_state.shared-vpc.outputs.host_project
    region  = var.gcp_region
}*/

resource "google_compute_global_forwarding_rule" "default" {
  name       = "global-rule"
  project          = data.terraform_remote_state.shared-vpc.outputs.host_project
  target     = google_compute_target_http_proxy.default.id
 # ip_address = google_compute_address.lb.address
  port_range = "80"
}