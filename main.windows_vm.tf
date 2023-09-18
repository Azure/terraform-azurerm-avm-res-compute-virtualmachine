

resource "azurerm_windows_virtual_machine" "this" {
  name                = var.virtualmachine_name
  resource_group_name = data.azurerm_resource_group.virtualmachine_deployment.name
  location            = data.azurerm_resource_group.virtualmachine_deployment.location
  size                = var.virtualmachine_sku_size
  admin_username      = var.admin_username
  admin_password      = var.generate_admin_password ? random_password.admin_password.result: data.azurerm_key_vault_secret.admin_password.value


  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  
}


