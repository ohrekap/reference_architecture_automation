terraform {
  required_version = ">= 0.12, < 0.13"
}

variable deployment_name {
  description = "Name of the deployment. This name will prefix the resources so it is easy to determine which resources are part of this deployment."
  type = string
  default = "Reference Architecture"
}

variable vpc_cidr_block {
  description = "CIDR block for the Management VPC. Code supports /16 Mask trough /29"
  type = string
  default = "10.255.0.0/16"
}

variable enable_ha {
  description = "If enabled, deploy the resources for a HA pair of Panoramas instead of a single Panorama"
  type = bool
  default = true
}

variable gcp_region {
  default = "us-west1"
}

variable onprem_IPaddress {}

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
  project = module.management-project.project_id
  region  = var.gcp_region
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

module "newbits" {
  source = "../modules/subnetting/"
  cidr_block = var.vpc_cidr_block
}

module "management-project" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 9.0"

  random_project_id    = true
  name                 = "management-project"
  org_id               = data.google_folder.this.organization
  folder_id            = data.google_folder.this.id
  billing_account      = data.google_billing_account.this.id
  skip_gcloud_download = true

  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "dataproc.googleapis.com",
    "dataflow.googleapis.com",
  ]
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 2.1.0"

  project_id   = module.management-project.project_id
  network_name = "management"

  delete_default_internet_gateway_routes = false
  #shared_vpc_host                        = true

  subnets = [
    {
      subnet_name   = "mgmt"
      subnet_ip     = cidrsubnet(var.vpc_cidr_block, module.newbits.newbits, 0)
      subnet_region =  var.gcp_region
    }
  ]

}

resource "google_compute_firewall" "panorama-mgmt" {
  name    = "panorama-mgmt"
  project = module.management-project.project_id
  network = module.vpc.network_self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "443"]
  }

  source_ranges = [var.onprem_IPaddress]
  target_tags   = ["panorama"]
}

resource "google_compute_firewall" "panorama-vmseries" {
  name    = "panorama-vmseries"
  project  = module.management-project.project_id
  network = module.vpc.network_self_link

  allow {
    protocol = "all"
  }

  source_ranges = [var.vpc_cidr_block]
}

module "panorama" {
  source = "../modules/panorama/"
  name                = "panorama"
  project             = module.management-project.project_id
  gcp_region          = var.gcp_region
  enable_ha           = var.enable_ha
  subnet_cidr_block   = module.vpc.subnets_ips[0]
  ra_key              = var.ra_key
  availability_zones  = local.availability_zones
  subnet              = module.vpc.subnets_self_links[0]
}

output "primary_eip" {
  value = module.panorama.primary_ip
}

output "secondary_eip" {
  value = module.panorama.secondary_ip
}

output "primary_private_ip" {
  value = module.panorama.primary_private_ip
}

output "secondary_private_ip" {
  value = module.panorama.secondary_private_ip
}

output "vpc" {
  value = module.vpc.network_self_link
}