resource "azurerm_managed_disk" "this" {
  for_each = (length(var.data_disk_managed_disks) > 0) ? { for disk in var.data_disk_managed_disks : "${disk.name}${local.name_string}" => disk } : {}

  name                 = each.key
  location             = data.azurerm_resource_group.virtualmachine_deployment.location
  resource_group_name  = data.azurerm_resource_group.virtualmachine_deployment.name
  storage_account_type = each.value.storage_account_type
  create_option        = each.value.create_option
  #disk_iops_read_write              = each.value.disk_iops_read_write
  #disk_mbps_read_write              = each.value.disk_mbps_read_write
  #disk_iops_read_only               = each.value.disk_iops_read_only
  #disk_mbps_read_only               = each.value.disk_mbps_read_only
  upload_size_bytes          = each.value.upload_size_bytes
  disk_size_gb               = each.value.disk_size_gb
  edge_zone                  = each.value.edge_zone
  hyper_v_generation         = each.value.hyper_v_generation
  image_reference_id         = each.value.image_reference_resource_id
  gallery_image_reference_id = each.value.gallery_image_reference_resource_id
  #logical_sector_size               = each.value.logical_sector_size
  optimized_frequent_attach_enabled = each.value.optimized_frequent_attach_enabled
  performance_plus_enabled          = each.value.performance_plus_enabled
  os_type                           = each.value.os_type
  source_resource_id                = each.value.source_resource_id
  source_uri                        = each.value.source_uri
  storage_account_id                = each.value.storage_account_resource_id
  tier                              = each.value.tier
  max_shares                        = each.value.max_shares
  trusted_launch_enabled            = each.value.trusted_launch_enabled
  security_type                     = each.value.security_type
  secure_vm_disk_encryption_set_id  = each.value.secure_vm_disk_encryption_set_resource_id
  on_demand_bursting_enabled        = each.value.on_demand_bursting_enabled
  tags                              = each.value.tags
  zone                              = each.value.zone
  network_access_policy             = each.value.network_access_policy
  disk_access_id                    = each.value.disk_access_resource_id
  public_network_access_enabled     = each.value.public_network_access_enabled

  dynamic "encryption_settings" {
    for_each = each.value.encryption_settings


    content {
      disk_encryption_key {
        secret_url      = encryption_settings.value.disk_encryption_key_vault_secret_url
        source_vault_id = encryption_settings.value.disk_encryption_key_vault_resource_id
      }

      key_encryption_key {
        key_url         = encryption_settings.value.key_encryption_key_vault_secret_url
        source_vault_id = encryption_settings.value.key_encryption_key_vault_resource_id
      }
    }
  }

  #disk_encryption_set_id = disk_encryption_set_resource_id #preview feature to be activated at a later date

}


resource "azurerm_virtual_machine_data_disk_attachment" "this_linux" {
  for_each                  = (length(var.data_disk_managed_disks) > 0) && (lower(var.virtualmachine_os_type) == "linux") ? { for disk in var.data_disk_managed_disks : "${disk.name}${local.name_string}" => disk } : {}
  managed_disk_id           = azurerm_managed_disk.this[each.key].id
  virtual_machine_id        = azurerm_linux_virtual_machine.this[0].id
  lun                       = each.value.lun
  caching                   = each.value.caching
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

resource "azurerm_virtual_machine_data_disk_attachment" "this_windows" {
  for_each                  = (length(var.data_disk_managed_disks) > 0) && (lower(var.virtualmachine_os_type) == "windows") ? { for disk in var.data_disk_managed_disks : "${disk.name}${local.name_string}" => disk } : {}
  managed_disk_id           = azurerm_managed_disk.this[each.key].id
  virtual_machine_id        = azurerm_windows_virtual_machine.this[0].id
  lun                       = each.value.lun
  caching                   = each.value.caching
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}