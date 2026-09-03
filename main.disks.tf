moved {
  from = azurerm_managed_disk.this
  to   = azapi_resource.this_data_disk
}

resource "azapi_resource" "this_data_disk" {
  for_each = var.data_disk_managed_disks

  location            = var.location
  name                = each.value.name
  parent_id           = local.data_disk_parent_ids[each.key]
  type                = var.resource_types.compute_disks
  body                = local.data_disk_bodies[each.key]
  create_headers      = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers      = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes = length(var.ignore_body_changes.compute_disks) > 0 ? var.ignore_body_changes.compute_disks : null
  read_headers        = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs = [
    # The azurerm provider marks these attributes ForceNew, so editing one destroyed and recreated
    # the disk. Under AzAPI they are ordinary body members and would otherwise be planned as an
    # in-place update that ARM then rejects at apply time. Naming them here preserves the previous
    # behaviour and keeps the replacement visible in the plan. Lint requires the list to be
    # statically known, so it cannot be lifted into a local.
    "properties.creationData.createOption",
    "properties.creationData.storageAccountId",
    "properties.creationData.imageReference",
    "properties.creationData.galleryImageReference",
    "properties.creationData.sourceUri",
    "properties.creationData.sourceResourceId",
    "properties.creationData.uploadSizeBytes",
    "properties.creationData.logicalSectorSize",
    "properties.creationData.performancePlus",
    "properties.hyperVGeneration",
    "properties.securityProfile.securityType",
    "properties.securityProfile.secureVMDiskEncryptionSetId",
  ]
  response_export_values = ["properties.diskSizeBytes", "properties.uniqueId"]
  retry                  = var.retry
  tags                   = each.value.tags != null && each.value.tags != {} ? each.value.tags : local.tags
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
    precondition {
      condition     = local.data_disk_parent_ids[each.key] != null
      error_message = "Unable to determine the subscription for data disk '${each.key}'. Set `parent_id` to the resource group resource ID, or supply `private_ip_subnet_resource_id` on at least one IP configuration so the subscription can be derived from it."
    }
    precondition {
      condition     = !(each.value.trusted_launch_enabled == true && each.value.security_type != null)
      error_message = "Data disk '${each.key}' sets both `trusted_launch_enabled` and `security_type`. ARM stores a single security type on the disk, so the two are mutually exclusive."
    }
  }
}

#attach the disk(s) to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "this_linux" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if(lower(var.os_type) == "linux") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = azapi_resource.this_data_disk[each.key].id
  virtual_machine_id        = azapi_resource.this_linux_virtual_machine[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

resource "azurerm_virtual_machine_data_disk_attachment" "this_windows" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if(lower(var.os_type) == "windows") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = azapi_resource.this_data_disk[each.key].id
  virtual_machine_id        = azapi_resource.this_windows_virtual_machine[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

#attach the disk(s) to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "this_linux_existing" {
  for_each = { for disk, values in var.data_disk_existing_disks : disk => values if(lower(var.os_type) == "linux") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = each.value.managed_disk_resource_id
  virtual_machine_id        = azapi_resource.this_linux_virtual_machine[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

resource "azurerm_virtual_machine_data_disk_attachment" "this_windows_existing" {
  for_each = { for disk, values in var.data_disk_existing_disks : disk => values if(lower(var.os_type) == "windows") }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = each.value.managed_disk_resource_id
  virtual_machine_id        = azapi_resource.this_windows_virtual_machine[0].id
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
  parent_id = azapi_resource.this_data_disk[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = each.value.lock_level
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
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
    azapi_resource.this_windows_virtual_machine,
    azapi_resource.this_linux_virtual_machine
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
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
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
    azapi_resource.this_windows_virtual_machine,
    azapi_resource.this_linux_virtual_machine,
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

  name                 = module.avm_utl_interfaces.role_assignments_azapi["disk-${each.key}"].name
  parent_id            = azapi_resource.this_data_disk[each.value.disk_key].id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_utl_interfaces.role_assignments_azapi["disk-${each.key}"].body
  create_headers       = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers       = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_null_property = true
  read_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  # Azure cannot change the principal or role definition of an existing role assignment, and the
  # azurerm resource treated both as ForceNew. The generated name is stable across such a change, so
  # without this the module would plan an in-place update that Azure rejects.
  replace_triggers_refs  = ["properties.principalId", "properties.roleDefinitionId"]
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
