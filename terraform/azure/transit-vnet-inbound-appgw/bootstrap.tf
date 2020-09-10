resource "azurerm_storage_share_directory" "inbound" {
  name                 = "inbound"
  share_name           = data.terraform_remote_state.transit.outputs.sa_share
  storage_account_name = data.terraform_remote_state.transit.outputs.sa_name
}

resource "azurerm_storage_share_directory" "inbound-config" {
  name                 = "${azurerm_storage_share_directory.inbound.name}/config"
  share_name           = data.terraform_remote_state.transit.outputs.sa_share
  storage_account_name = data.terraform_remote_state.transit.outputs.sa_name
}

resource "azurerm_storage_share_directory" "inbound-software" {
  name                 = "${azurerm_storage_share_directory.inbound.name}/software"
  share_name           = data.terraform_remote_state.transit.outputs.sa_share
  storage_account_name = data.terraform_remote_state.transit.outputs.sa_name
}

resource "azurerm_storage_share_directory" "inbound-content" {
  name                 = "${azurerm_storage_share_directory.inbound.name}/content"
  share_name           = data.terraform_remote_state.transit.outputs.sa_share
  storage_account_name = data.terraform_remote_state.transit.outputs.sa_name
}

resource "azurerm_storage_share_directory" "inbound-license" {
  name                 = "${azurerm_storage_share_directory.inbound.name}/license"
  share_name           = data.terraform_remote_state.transit.outputs.sa_share
  storage_account_name = data.terraform_remote_state.transit.outputs.sa_name
}

resource "null_resource" "inbound" {
    triggers = {
        cluster_instance_ids = local.bootstrap_inbound_local-exec
    }
    
    provisioner "local-exec" {
        command = local.bootstrap_inbound_local-exec
        interpreter = ["/bin/bash", "-c"]
    }
    depends_on = [azurerm_storage_share_directory.inbound-config, azurerm_storage_share_directory.inbound-license]
}