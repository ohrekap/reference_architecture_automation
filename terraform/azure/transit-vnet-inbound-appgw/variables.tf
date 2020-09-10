variable deployment_name {
  description = "Name of the deployment. This name will prefix the resources so it is easy to determine which resources are part of this deployment."
  type = string
  default = ""
}

variable password {
  type = string
}

variable panorama_bootstrap_key {}

variable authcode {}