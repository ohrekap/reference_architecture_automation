terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "panos" {
    hostname = data.terraform_remote_state.panorama.outputs.primary_eip
    version = "~> 1.6"
}

variable deployment_name {
  description = "Name of the deployment. This name will prefix the resources so it is easy to determine which resources are part of this deployment."
  type = string
  default = "Reference Architecture"
}

variable gcp_region {
  default = "us-west1"
}

variable authcode {}
variable ra_key {}
variable folder {}
variable billing_account {}

data "google_folder" "this" {
  folder              = var.folder
  lookup_organization = true
}

data "google_billing_account" "this" {
  billing_account = var.billing_account
  open            = true
}

data "google_compute_zones" "available" {
  project = data.terraform_remote_state.shared-vpc.outputs.host_project
  region  = var.gcp_region
}

data "terraform_remote_state" "panorama" {
  backend = "local"

  config = {
    path = "../panorama/terraform.tfstate"
  }
}

data "terraform_remote_state" "shared-vpc" {
  backend = "local"

  config = {
    path = "../shared-vpc-deploy/terraform.tfstate"
  }
}

provider "google" {
  version = "~> 3.30"
}

provider "google-beta" {
  version = "~> 3.30"
}

provider "null" {
  version = "~> 2.1"
}

provider "random" {
  version = "~> 2.2"
}

locals {
 availability_zones = data.google_compute_zones.available.names

}

resource "google_compute_instance" "web-1" {
  name          = "web-1"
  project = data.terraform_remote_state.shared-vpc.outputs.web_project
  machine_type              = "f1-micro"
  zone                      = local.availability_zones[0]
  can_ip_forward            = false
  allow_stopping_for_update = true
  #metadata_startup_script   = "${var.startup_script}"

  metadata = {
    serial-port-enable = true
    sshKeys            = var.ra_key
    startup-script     = <<-EOF
                    #!/bin/bash
                    sudo apt-get update
                    sudo apt-get install -y apache2
                    echo "<p> First Instance </p>" >> /var/www/html/index.html
                    sudo systemctl enable apache2
                    sudo systemctl start apache2
                    EOF
  }

  network_interface {
    subnetwork = data.terraform_remote_state.shared-vpc.outputs.web_subnet
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2004-lts"
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group" "web-1" {
    name = "application-group-${local.availability_zones[0]}"
    project = data.terraform_remote_state.shared-vpc.outputs.web_project
    zone = local.availability_zones[0]
    instances = [google_compute_instance.web-1.id]
}

resource "google_compute_instance" "web-2" {
  name          = "web-2"
  project = data.terraform_remote_state.shared-vpc.outputs.web_project
  machine_type              = "f1-micro"
  zone                      = local.availability_zones[1]
  can_ip_forward            = false
  allow_stopping_for_update = true
  #metadata_startup_script   = "${var.startup_script}"

  metadata = {
    serial-port-enable = true
    sshKeys            = var.ra_key
    startup-script     = <<-EOF
                    #!/bin/bash
                    sudo apt-get update
                    sudo apt-get install -y apache2
                    echo "<p> Second Instance </p>" >> /var/www/html/index.html
                    sudo systemctl enable apache2
                    sudo systemctl start apache2
                    EOF
  }

  network_interface {
    subnetwork = data.terraform_remote_state.shared-vpc.outputs.web_subnet
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2004-lts"
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group" "web-2" {
    name = "application-group-${local.availability_zones[1]}"
    project = data.terraform_remote_state.shared-vpc.outputs.web_project
    zone = local.availability_zones[1]
    instances = [google_compute_instance.web-2.id]
}

resource "google_compute_health_check" "health-check" {
    name = "obew-vmseries-health-check"
    project  = data.terraform_remote_state.shared-vpc.outputs.web_project
    timeout_sec        = 2
    check_interval_sec = 2

    http_health_check {
        port = "80"
    }
}

resource "google_compute_region_backend_service" "app-backend" {
    name             = "application-lb"
    project          = data.terraform_remote_state.shared-vpc.outputs.web_project
    region           = var.gcp_region
    protocol         = "TCP"
    #network          = module.private-vpc.network_self_link
    health_checks    = [google_compute_health_check.health-check.id]
    #session_affinity = "CLIENT_IP"

    backend {
        group = google_compute_instance_group.web-1.self_link
    }

    backend {
        group = google_compute_instance_group.web-2.self_link
    }
}

resource "google_compute_forwarding_rule" "default" {
    name   = "application-frontend"
    region = var.gcp_region
    project          = data.terraform_remote_state.shared-vpc.outputs.web_project
    load_balancing_scheme = "INTERNAL"
    backend_service       = google_compute_region_backend_service.app-backend.id
    ports             = [80]
    network               = data.terraform_remote_state.shared-vpc.outputs.web_network
    subnetwork            = data.terraform_remote_state.shared-vpc.outputs.web_subnet
}