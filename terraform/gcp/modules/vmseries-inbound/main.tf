variable name {}

variable project {}

variable gcp_region {}

variable ra_key {}

variable availability_zone {}

variable public_subnet {}

variable public_ip {}

variable private_subnet {}

variable private_ip {}

variable mgmt_subnet {}

variable mgmt_ip {}

variable bootstrap_bucket {}

locals {
    machine_type = "n1-standard-4"
    cpu_platform = "Intel Skylake"
}

resource "google_compute_address" "mgmt" {
    name    = "${var.name}-mgmt"
    project = var.project
    region  = var.gcp_region
}

resource "google_compute_address" "public" {
    name    = "${var.name}-public"
    project = var.project
    region  = var.gcp_region
}

resource "google_compute_instance" "this" {
    project                   = var.project
    name                      = var.name
    machine_type              = local.machine_type
    zone                      = var.availability_zone
    min_cpu_platform          = local.cpu_platform
    can_ip_forward            = true
    allow_stopping_for_update = true
    tags                      = ["vm-series", "vm-series-inbound"]

    metadata = {
        vmseries-bootstrap-gce-storagebucket = var.bootstrap_bucket 
        mgmt-interface-swap = "enable"
        serial-port-enable  = true
        ssh-keys            = var.ra_key
    }

    service_account {
        scopes = ["cloud-platform"]
    }

    network_interface {
        subnetwork =  var.public_subnet
        network_ip =  var.public_ip
        access_config {
            nat_ip = google_compute_address.public.address
        }
    }

    network_interface {
        subnetwork =  var.mgmt_subnet
        network_ip =  var.mgmt_ip 
        access_config {
            nat_ip = google_compute_address.mgmt.address
        }
    }

    network_interface {
        subnetwork =  var.private_subnet
        network_ip =  var.private_ip
    }

    boot_disk {
        initialize_params {
            image = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-flex-byol-913"
            type  = "pd-standard"
        }
    }
}

resource "google_compute_instance_group" "this" {
    name = "inbound-group-${var.availability_zone}"
    project = var.project
    zone = var.availability_zone
    instances = [google_compute_instance.this.id]
}

output instance_group {
    value = google_compute_instance_group.this.self_link
}