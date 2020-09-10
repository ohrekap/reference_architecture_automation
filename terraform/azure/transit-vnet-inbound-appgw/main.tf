terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "azurerm" {
  version = "=2.24.0"
  features {}
}

provider "panos" {
    hostname = data.terraform_remote_state.panorama.outputs.primary_eip
    version = "~> 1.6"
}

provider "null" {
  version = "~> 2.1"
}

locals {
  #name = "${var.deployment_name != "" ? "${var.deployment_name}-${var.vpc_name}" : var.vpc_name}"
  deployment_name = "${var.deployment_name != "" ? "${var.deployment_name}" : ""}"
  vmseriesVersion = "9.1.3"
  # I am defining the commands here because if you do it in the null provisioner then it won't adjust the configuration if you make a change to the command.
  # Defining it as a local variable allows for the provisioner to use this variable as a trigger
  # The authcodes file must have a . at the end. Otherwise Azure thinks it is a directory
  bootstrap_inbound_local-exec = <<-EOF
    echo "type=dhcp-client
    panorama-server=${data.terraform_remote_state.panorama.outputs.primary_private_ip}
    panorama-server=${data.terraform_remote_state.panorama.outputs.secondary_private_ip}
    tplname=${panos_panorama_template_stack.inbound.name}
    dgname=${panos_panorama_device_group.inbound.name}
    dns-primary=168.63.129.16
    vm-auth-key=${var.panorama_bootstrap_key}
    dhcp-accept-server-hostname=yes
    dhcp-accept-server-domain=yes" > init-cfg.txt && az storage file upload \
    --account-name ${data.terraform_remote_state.transit.outputs.sa_name} \
    --account-key ${data.terraform_remote_state.transit.outputs.sa_key} \
    --share-name ${data.terraform_remote_state.transit.outputs.sa_share} \
    --source "init-cfg.txt" \
    --path "${azurerm_storage_share_directory.inbound-config.name}/init-cfg.txt" \
    && rm init-cfg.txt && echo "${var.authcode}" > authcodes && az storage file upload \
    --account-name ${data.terraform_remote_state.transit.outputs.sa_name} \
    --account-key ${data.terraform_remote_state.transit.outputs.sa_key} \
    --share-name ${data.terraform_remote_state.transit.outputs.sa_share} \
    --source "authcodes" \
    --path "${azurerm_storage_share_directory.inbound-license.name}/authcodes." \
    && rm authcodes
    EOF
  
}

data "terraform_remote_state" "panorama" {
  backend = "local"

  config = {
    path = "../panorama/terraform.tfstate"
  }
}

data "terraform_remote_state" "transit" {
  backend = "local"

  config = {
    path = "../transit-vnet-deploy/terraform.tfstate"
  }
}



# This module figures out how many bits to add to get a /24. Also supports smaller subnets if the starting
# network is smaller than a /25. In that case it will divide it into two subnets.
module "newbits" {
  source = "../modules/subnetting/"
  cidr_block = data.terraform_remote_state.transit.outputs.private_block
}

resource "azurerm_availability_set" "inbound" {
  name                        = "${data.terraform_remote_state.transit.outputs.rg_name}-inbound"
  location                    = data.terraform_remote_state.transit.outputs.rg_location
  resource_group_name         = data.terraform_remote_state.transit.outputs.rg_name
  # https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/managed-disks-common-fault-domain-region-list.md
  platform_fault_domain_count = 2
}

output "appgw_ip" {
  value = azurerm_public_ip.this.fqdn
}
