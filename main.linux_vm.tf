resource "azurerm_linux_virtual_machine" "this" {
  count = (lower(var.virtualmachine_os_type) == "linux") ? 1 : 0

  name                = var.virtualmachine_name
  resource_group_name = data.azurerm_resource_group.virtualmachine_deployment.name
  location            = data.azurerm_resource_group.virtualmachine_deployment.location
  size                = var.virtualmachine_sku_size
  admin_username      = var.admin_username
  admin_password = (var.disable_password_authentication ? null :
  (var.generate_admin_password_or_ssh_key ? random_password.admin_password[0].result : data.azurerm_key_vault_secret.admin_password[0].value))
  network_interface_ids = [ for interface in azurerm_network_interface.virtualmachine_network_interfaces : interface.id ]
  source_image_id       = var.source_image_resource_id


  dynamic "source_image_reference" {
    for_each = var.source_image_resource_id == null ? ["source_image_reference"] : []

    content {
      publisher = local.source_image_reference.publisher
      offer     = local.source_image_reference.offer
      sku       = local.source_image_reference.sku
      version   = local.source_image_reference.version
    }
  }

  os_disk {
    caching                          = var.os_disk.caching
    storage_account_type             = var.os_disk.storage_account_type
    disk_encryption_set_id           = var.os_disk.disk_encryption_set_id
    disk_size_gb                     = var.os_disk.disk_size_gb
    name                             = var.os_disk.name
    secure_vm_disk_encryption_set_id = var.os_disk.secure_vm_disk_encryption_set_id
    security_encryption_type         = var.os_disk.security_encryption_type
    write_accelerator_enabled        = var.os_disk.write_accelerator_enabled

    dynamic "diff_disk_settings" {
      for_each = var.os_disk.diff_disk_settings == null ? [] : [
        "diff_disk_settings"
      ]

      content {
        option    = var.os_disk.diff_disk_settings.option
        placement = var.os_disk.diff_disk_settings.placement
      }
    }
  }

  dynamic "admin_ssh_key" {
    for_each = { for key in local.admin_ssh_keys : key.username => key }

    content {
      public_key = admin_ssh_key.value.public_key
      username   = admin_ssh_key.value.username
    }
  }

}


