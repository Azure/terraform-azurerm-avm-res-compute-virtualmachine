resource "azurerm_managed_disk" "this" {
  for_each = var.data_disk_managed_disks

  create_option                     = each.value.create_option
  location                          = var.location
  name                              = each.value.name
  resource_group_name               = coalesce(each.value.resource_group_name, var.resource_group_name)
  storage_account_type              = each.value.storage_account_type
  disk_access_id                    = each.value.disk_access_resource_id
  disk_encryption_set_id            = each.value.disk_encryption_set_resource_id #preview feature to be activated at a later date
  disk_iops_read_only               = each.value.disk_iops_read_only
  disk_iops_read_write              = each.value.disk_iops_read_write
  disk_mbps_read_only               = each.value.disk_mbps_read_only
  disk_mbps_read_write              = each.value.disk_mbps_read_write
  disk_size_gb                      = each.value.disk_size_gb
  edge_zone                         = var.edge_zone #each.value.edge_zone
  gallery_image_reference_id        = each.value.gallery_image_reference_resource_id
  hyper_v_generation                = each.value.hyper_v_generation
  image_reference_id                = each.value.image_reference_resource_id
  logical_sector_size               = each.value.logical_sector_size
  max_shares                        = each.value.max_shares
  network_access_policy             = each.value.network_access_policy
  on_demand_bursting_enabled        = each.value.on_demand_bursting_enabled
  optimized_frequent_attach_enabled = each.value.optimized_frequent_attach_enabled
  os_type                           = each.value.os_type
  performance_plus_enabled          = each.value.performance_plus_enabled
  public_network_access_enabled     = each.value.public_network_access_enabled
  secure_vm_disk_encryption_set_id  = each.value.secure_vm_disk_encryption_set_resource_id
  security_type                     = each.value.security_type
  source_resource_id                = each.value.source_resource_id
  source_uri                        = each.value.source_uri
  storage_account_id                = each.value.storage_account_resource_id
  tags                              = each.value.tags != null && each.value.tags != {} ? each.value.tags : local.tags
  tier                              = each.value.tier
  trusted_launch_enabled            = each.value.trusted_launch_enabled
  upload_size_bytes                 = each.value.upload_size_bytes
  zone                              = strcontains(each.value.storage_account_type, "ZRS") ? null : var.zone

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
}

#attach the disk(s) to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "this_linux" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if(lower(var.os_type) == "linux") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = azurerm_managed_disk.this[each.key].id
  virtual_machine_id        = azurerm_linux_virtual_machine.this[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

resource "azurerm_virtual_machine_data_disk_attachment" "this_windows" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if(lower(var.os_type) == "windows") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = azurerm_managed_disk.this[each.key].id
  virtual_machine_id        = azurerm_windows_virtual_machine.this[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

#attach the disk(s) to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "this_linux_existing" {
  for_each = { for disk, values in var.data_disk_existing_disks : disk => values if(lower(var.os_type) == "linux") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = each.value.managed_disk_resource_id
  virtual_machine_id        = azurerm_linux_virtual_machine.this[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

resource "azurerm_virtual_machine_data_disk_attachment" "this_windows_existing" {
  for_each = { for disk, values in var.data_disk_existing_disks : disk => values if(lower(var.os_type) == "windows") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = each.value.managed_disk_resource_id
  virtual_machine_id        = azurerm_windows_virtual_machine.this[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

moved {
  from = azurerm_management_lock.this-disk
  to   = azurerm_management_lock.this_disk
}

moved {
  from = azurerm_management_lock.this_disk
  to   = azapi_resource.this_disk_lock
}

#configure resource locks on each Data Disk if the lock values are set. Set explicit dependencies on the attachments and vm's to ensure provisioning is complete prior to setting resource locks
resource "azapi_resource" "this_disk_lock" {
  for_each = { for disk, diskvalues in var.data_disk_managed_disks : disk => diskvalues if diskvalues.lock_level != null }

  name      = coalesce(each.value.lock_name, "${each.key}-lock")
  parent_id = azurerm_managed_disk.this[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = each.value.lock_level
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows,
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this
  ]
}

moved {
  from = azurerm_management_lock.this_os_disk
  to   = azapi_resource.this_os_disk_lock
}

#configure a resource lock on the OS Disk if the lock values are set. The OS Disk is an inline block on the virtual
#machine resource, so the lock is scoped to the disk id read back off the created virtual machine. The dependencies
#ensure the disk is fully provisioned before a lock is applied, since a ReadOnly lock blocks subsequent writes.
resource "azapi_resource" "this_os_disk_lock" {
  count = var.os_disk.lock_level != null ? 1 : 0

  name      = coalesce(var.os_disk.lock_name, "${var.name}-os-disk-lock")
  parent_id = local.os_disk_resource_id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.os_disk.lock_level
      notes = local.interface_lock_notes[var.os_disk.lock_level]
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows,
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    module.extension
  ]
}

moved {
  from = azurerm_role_assignment.disks
  to   = azapi_resource.disks_role_assignments
}

#assign permissions to the virtual machine if enabled and role assignments included
resource "azapi_resource" "disks_role_assignments" {
  for_each = local.disks_role_assignments

  name                   = module.avm_utl_interfaces.role_assignments_azapi["disk-${each.key}"].name
  parent_id              = azurerm_managed_disk.this[each.value.disk_key].id
  type                   = var.resource_types.authorization_role_assignments
  body                   = module.avm_utl_interfaces.role_assignments_azapi["disk-${each.key}"].body
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_null_property   = true
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    # ARM requires a GUID name. AzureRM generated a random one that configuration cannot observe, so
    # a fresh GUID is computed here and would force replacement. Replacement is not merely a brief
    # permissions gap: deleting a role assignment scoped to a resource that carries a CanNotDelete
    # lock fails with ScopeLocked, which aborts the upgrade partway through. Keep whatever name the
    # assignment already has; the value is an opaque identifier that no consumer should need to set.
    ignore_changes = [name]
  }
}
