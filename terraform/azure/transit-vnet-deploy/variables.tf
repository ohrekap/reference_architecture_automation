variable azure_region {
  type = string
  default = "westus"
}

variable deployment_name {
  description = "Name of the deployment. This name will prefix the resources so it is easy to determine which resources are part of this deployment."
  type = string
  default = ""
}

variable vpc_name {
  description = "Name of the Transit Vnet"
  type = string
  default = "Transit"
}

variable vpc_cidr_block {
  description = "CIDR block for the Transit VNet. Code supports /16 Mask trough /29"
  type = string
  default = "10.110.0.0/16"
}

variable onprem_IPaddress {
  description = "IP and mask of the network that will be accessing the VM-Series"
  type = string
}

variable password {
  type = string
}

variable panorama_bootstrap_key {
}

variable authcode {}