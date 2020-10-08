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
variable host_public_block {}
variable host_private_block {}
variable host_mgmt_block {}
variable web_block {}
variable db_block {}
variable container_block {}
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
  project = module.host-project.project_id
  region  = var.gcp_region
}

data "terraform_remote_state" "panorama" {
  backend = "local"

  config = {
    path = "../panorama/terraform.tfstate"
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

module "host-project" {
    #source  = "terraform-google-modules/project-factory/google"
    # There us a defect in the 9.1 code and I needed to pull the latest direct from github.
    # Replace with 9.2 when it is released.
    source                          = "github.com/terraform-google-modules/terraform-google-project-factory"
    random_project_id               = true
    name                            = "host-project"
    org_id                          = data.google_folder.this.organization
    folder_id                       = data.google_folder.this.id
    billing_account                 = data.google_billing_account.this.id
    skip_gcloud_download            = true
    disable_services_on_destroy     = false
    enable_shared_vpc_host_project  = true
    default_service_account         = "keep"

    activate_apis = [
        "compute.googleapis.com",
        "dataproc.googleapis.com",
        "dataflow.googleapis.com",
        "storage-component.googleapis.com"
    ]
}

module "management-vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 2.1.0"

    project_id   = module.host-project.project_id
    network_name = "management"

    delete_default_internet_gateway_routes = false

    subnets = [
        {
        subnet_name   = "mgmt"
        subnet_ip     = var.host_mgmt_block
        subnet_region = var.gcp_region
        }
    ]

}

module "public-vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 2.1.0"

    project_id   = module.host-project.project_id
    network_name = "public"

    delete_default_internet_gateway_routes = false

    subnets = [
        {
        subnet_name   = "public"
        subnet_ip     = var.host_public_block
        subnet_region = var.gcp_region
        }
    ]

}

module "private-vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 2.1.0"

    project_id   = module.host-project.project_id
    network_name = "private"

    delete_default_internet_gateway_routes = true

    subnets = [
        {
        subnet_name   = "fw"
        subnet_ip     = var.host_private_block
        subnet_region = var.gcp_region
        }
    ]

}

module "web-vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 2.1.0"

    project_id   = module.host-project.project_id
    network_name = "web"

    delete_default_internet_gateway_routes = true

    subnets = [
        {
        subnet_name   = "web"
        subnet_ip     = var.web_block
        subnet_region = var.gcp_region
        }
    ]

}

module "db-vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 2.1.0"

    project_id   = module.host-project.project_id
    network_name = "db"

    delete_default_internet_gateway_routes = true

    subnets = [
        {
        subnet_name   = "db"
        subnet_ip     = var.db_block
        subnet_region = var.gcp_region
        }
    ]

}

module "peering-management" {
  source = "terraform-google-modules/network/google//modules/network-peering"

  local_network = module.management-vpc.network_self_link
  peer_network  = data.terraform_remote_state.panorama.outputs.vpc
}

module "peering-private_web" {
  source = "terraform-google-modules/network/google//modules/network-peering"

  local_network = module.private-vpc.network_self_link
  peer_network  = module.web-vpc.network_self_link
  export_local_custom_routes = true
}

module "peering-private_db" {
  source = "terraform-google-modules/network/google//modules/network-peering"

  local_network = module.private-vpc.network_self_link
  peer_network  = module.db-vpc.network_self_link
  export_local_custom_routes = true

  module_depends_on = [module.peering-private_web.complete]
}

module "web-project" {
    source = "terraform-google-modules/project-factory/google//modules/shared_vpc"
    version = "~> 9.1"

    name                = "web-project"
    random_project_id   = true

    org_id              = data.google_folder.this.organization
    folder_id           = data.google_folder.this.id
    billing_account     = data.google_billing_account.this.id
    shared_vpc_enabled  = true

    shared_vpc          = module.host-project.project_id
    shared_vpc_subnets  = module.web-vpc.subnets_self_links

    activate_apis = [
        "compute.googleapis.com",
        "container.googleapis.com",
        "dataproc.googleapis.com",
        "dataflow.googleapis.com",
    ]

    disable_services_on_destroy = false
    skip_gcloud_download        = true
}

module "db-project" {
    source = "terraform-google-modules/project-factory/google//modules/shared_vpc"
    version = "~> 9.1"

    name                = "db-project"
    random_project_id   = true

    org_id              = data.google_folder.this.organization
    folder_id           = data.google_folder.this.id
    billing_account     = data.google_billing_account.this.id
    shared_vpc_enabled  = true

    shared_vpc          = module.host-project.project_id
    shared_vpc_subnets  = module.db-vpc.subnets_self_links

    activate_apis = [
        "compute.googleapis.com",
        "container.googleapis.com",
        "dataproc.googleapis.com",
        "dataflow.googleapis.com",
    ]

    disable_services_on_destroy = false
    skip_gcloud_download        = true
}