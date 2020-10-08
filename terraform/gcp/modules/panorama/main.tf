variable name {}

variable project {}

variable gcp_region {}

variable enable_ha {}

variable subnet_cidr_block {}

variable ra_key {}

variable availability_zones {}

variable subnet {}

locals {
    machine_type = "n1-standard-4"
    cpu_platform = "Intel Skylake"
}

resource "google_compute_address" "this" {
    name    = "${var.name}-a-external"
    project = var.project
    region  = var.gcp_region
}

resource "google_compute_instance" "this" {
    project                   = var.project
    name                      = "${var.name}-a"
    machine_type              = local.machine_type
    zone                      = var.availability_zones[0]
    min_cpu_platform          = local.cpu_platform
    can_ip_forward            = false
    allow_stopping_for_update = true
    tags                      = ["panorama"]

    metadata = {
        serial-port-enable  = true
        ssh-keys            = var.ra_key
    }

    service_account {
        scopes = ["cloud-platform"]
    }

    network_interface {
        subnetwork =  var.subnet
        network_ip =  cidrhost(var.subnet_cidr_block,4)
        access_config {
            nat_ip = google_compute_address.this.address
        }
    }

    boot_disk {
        initialize_params {
            image = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/panorama-byol-912"
            type  = "pd-standard"
        }
    }
}


resource "google_compute_address" "secondary" {
    count   = var.enable_ha ? 1 : 0
    name    = "${var.name}-b-external"
    project = var.project
    region  = var.gcp_region
}

resource "google_compute_instance" "secondary" {
    count                     = var.enable_ha ? 1 : 0
    project                   = var.project
    name                      = "${var.name}-b"
    machine_type              = local.machine_type
    zone                      = var.availability_zones[1]
    min_cpu_platform          = local.cpu_platform
    can_ip_forward            = false
    allow_stopping_for_update = true
    tags                      = ["panorama"]

    metadata = {
        serial-port-enable  = true
        ssh-keys            = var.ra_key
    }

    service_account {
        scopes = ["cloud-platform"]
    }

    network_interface {
        subnetwork =  var.subnet
        network_ip =  cidrhost(var.subnet_cidr_block,5)
        access_config {
            nat_ip = google_compute_address.secondary[0].address
        }
    }

    boot_disk {
        initialize_params {
            image = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/panorama-byol-912"
            type  = "pd-standard"
        }
    }
}


