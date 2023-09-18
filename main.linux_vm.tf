resource "azurerm_linux_virtual_machine" "this" {
  name                = var.virtualmachine_name
  resource_group_name = data.azurerm_resource_group.virtualmachine_deployment.name
  location            = data.azurerm_resource_group.virtualmachine_deployment.location
  size                = var.virtualmachine_sku_size
  admin_username      = var.admin_username

  
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}