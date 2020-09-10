resource "azurerm_storage_share" "this" {
  name                  = "bootstrap"
  storage_account_name  = azurerm_storage_account.this.name
  quota                 = 1
}

resource "azurerm_storage_share_directory" "obew" {
  name                 = "obew"
  share_name           = azurerm_storage_share.this.name
  storage_account_name = azurerm_storage_account.this.name
}

resource "azurerm_storage_share_directory" "obew-config" {
  name                 = "${azurerm_storage_share_directory.obew.name}/config"
  share_name           = azurerm_storage_share.this.name
  storage_account_name = azurerm_storage_account.this.name
}

resource "azurerm_storage_share_directory" "obew-software" {
  name                 = "${azurerm_storage_share_directory.obew.name}/software"
  share_name           = azurerm_storage_share.this.name
  storage_account_name = azurerm_storage_account.this.name
}

resource "azurerm_storage_share_directory" "obew-content" {
  name                 = "${azurerm_storage_share_directory.obew.name}/content"
  share_name           = azurerm_storage_share.this.name
  storage_account_name = azurerm_storage_account.this.name
}

resource "azurerm_storage_share_directory" "obew-license" {
  name                 = "${azurerm_storage_share_directory.obew.name}/license"
  share_name           = azurerm_storage_share.this.name
  storage_account_name = azurerm_storage_account.this.name
}

resource "null_resource" "this" {
    triggers = {
        cluster_instance_ids = local.bootstrap_local-exec
    }
    
    provisioner "local-exec" {
        command = local.bootstrap_local-exec
        interpreter = ["/bin/bash", "-c"]
    }
    depends_on = [azurerm_storage_share_directory.obew-config, azurerm_storage_share_directory.obew-license]
}