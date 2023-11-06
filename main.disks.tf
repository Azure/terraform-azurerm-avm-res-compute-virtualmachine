resource "azurerm_managed_disk" "this" {
  for_each = var.data_disk_managed_disks

  name                              = each.value.name
  location                          = local.location
  resource_group_name               = data.azurerm_resource_group.virtualmachine_deployment.name
  storage_account_type              = each.value.storage_account_type
  create_option                     = each.value.create_option
  upload_size_bytes                 = each.value.upload_size_bytes
  disk_size_gb                      = each.value.disk_size_gb
  edge_zone                         = each.value.edge_zone
  hyper_v_generation                = each.value.hyper_v_generation
  image_reference_id                = each.value.image_reference_resource_id
  gallery_image_reference_id        = each.value.gallery_image_reference_resource_id
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
  zone                              = each.value.zone
  network_access_policy             = each.value.network_access_policy
  disk_access_id                    = each.value.disk_access_resource_id
  public_network_access_enabled     = each.value.public_network_access_enabled
  disk_iops_read_write              = each.value.disk_iops_read_write
  disk_mbps_read_write              = each.value.disk_mbps_read_write
  disk_iops_read_only               = each.value.disk_iops_read_only
  disk_mbps_read_only               = each.value.disk_mbps_read_only
  logical_sector_size               = each.value.logical_sector_size
  tags                              = each.value.tags != null && each.value.tags != {} ? each.value.tags : local.tags

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

  disk_encryption_set_id = each.value.disk_encryption_set_resource_id #preview feature to be activated at a later date
  #tags                              = each.value.inherit_tags? merge(local.tags, each.value.tags) : each.value.tags

}

#attach the disk(s) to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "this_linux" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if(lower(var.virtualmachine_os_type) == "linux") }

  managed_disk_id           = azurerm_managed_disk.this[each.key].id
  virtual_machine_id        = azurerm_linux_virtual_machine.this[0].id
  lun                       = each.value.lun
  caching                   = each.value.caching
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

resource "azurerm_virtual_machine_data_disk_attachment" "this_windows" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if(lower(var.virtualmachine_os_type) == "windows") }

  managed_disk_id           = azurerm_managed_disk.this[each.key].id
  virtual_machine_id        = azurerm_windows_virtual_machine.this[0].id
  lun                       = each.value.lun
  caching                   = each.value.caching
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

#configure resource locks on each Data Disk if the lock values are set. Set explicit dependencies on the attachments and vm's to ensure provisioning is complete prior to setting resource locks
resource "azurerm_management_lock" "this-disk" {
  for_each = { for disk, diskvalues in var.data_disk_managed_disks : disk => diskvalues if coalesce(diskvalues.lock_level, var.lock.kind) != "None" }

  name       = coalesce(each.value.lock_name, "${each.key}-lock")
  scope      = azurerm_managed_disk.this[each.key].id
  lock_level = coalesce(each.value.lock_level, var.lock.kind)

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows,
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this
  ]
}

#assign permissions to the virtual machine if enabled and role assignments included
resource "azurerm_role_assignment" "disks" {
  for_each                               = local.disks_role_assignments
  scope                                  = azurerm_managed_disk.this[each.value.disk_key].id
  role_definition_id                     = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? each.value.role_assignment.role_definition_id_or_name : null
  role_definition_name                   = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? null : each.value.role_assignment.role_definition_id_or_name
  principal_id                           = each.value.role_assignment.principal_id
  condition                              = each.value.role_assignment.condition
  condition_version                      = each.value.role_assignment.condition_version
  skip_service_principal_aad_check       = each.value.role_assignment.skip_service_principal_aad_check
  delegated_managed_identity_resource_id = each.value.role_assignment.delegated_managed_identity_resource_id
}
