

resource "azurerm_windows_virtual_machine" "this" {
  count = (lower(var.virtualmachine_os_type) == "windows") ? 1 : 0

  name                = var.virtualmachine_name
  resource_group_name = data.azurerm_resource_group.virtualmachine_deployment.name
  location            = data.azurerm_resource_group.virtualmachine_deployment.location
  size                = var.virtualmachine_sku_size
  admin_username      = var.admin_username
  admin_password      = var.generate_admin_password_or_ssh_key ? random_password.admin_password[0].result : data.azurerm_key_vault_secret.admin_password[0].value


  network_interface_ids = [ for interface in azurerm_network_interface.virtualmachine_network_interfaces : interface.id ]

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


