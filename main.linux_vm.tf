moved {
  from = azurerm_linux_virtual_machine.this
  to   = azapi_resource.this_linux_virtual_machine
}

resource "azapi_resource" "this_linux_virtual_machine" {
  count = (lower(var.os_type) == "linux") ? 1 : 0

  location            = var.location
  name                = var.name
  parent_id           = local.parent_id_for_resource_group[var.resource_group_name]
  type                = var.resource_types.compute_virtual_machines
  body                = local.linux_vm_body
  ignore_body_changes = length(var.ignore_body_changes.compute_virtual_machines) > 0 ? var.ignore_body_changes.compute_virtual_machines : null
  # ARM returns the data disks in the order they were attached, which is not the order this module
  # sends them. Matching by name rather than by position stops that difference reading as a change
  # on every plan. name is also AzAPI's default identifier, but it is set explicitly because the
  # matching behaviour is not otherwise visible from the config.
  list_unique_id_property = {
    "properties.storageProfile.dataDisks" = "name"
  }
  replace_triggers_external_values = [
    # admin_password and custom_data are ForceNew under the azurerm provider and cannot be
    # changed in place by ARM. They live in sensitive_body, which is write-only and therefore
    # invisible to the plan, so a hash stands in for them here. See locals.linux_vm.tf.
    local.linux_vm_secret_fingerprint,
    # A body path may only be watched below when the module always sends a real value for it.
    # Anything the module can omit, or send as null so that the shape of the body stays readable,
    # differs from the body a moved block adopts from Azure and would replace the machine. The
    # inputs behind those paths are watched here instead, and they still force replacement exactly
    # as the azurerm provider did.
    var.os_disk.name,
    var.os_managed_disk_id,
    var.os_disk.security_encryption_type,
    var.os_disk.secure_vm_disk_encryption_set_id,
    var.source_image_resource_id,
    jsonencode(local.source_image_reference),
    jsonencode(local.linux_vm_ssh_public_keys),
  ]
  replace_triggers_refs = [
    # Every path the azurerm provider marked ForceNew that the module always sends a real value
    # for. Under AzAPI these are ordinary body members, so without this an immutable edit would
    # plan as an in-place update and then fail at apply.
    "properties.osProfile.adminUsername",
    "properties.osProfile.computerName",
    "properties.osProfile.linuxConfiguration.disablePasswordAuthentication",
    "properties.osProfile.linuxConfiguration.provisionVMAgent",
    "properties.storageProfile.osDisk.diffDiskSettings",
    "properties.storageProfile.osDisk.managedDisk.storageAccountType",
    "properties.securityProfile.uefiSettings",
    "properties.availabilitySet",
    "properties.platformFaultDomain",
    "properties.priority",
    "properties.evictionPolicy",
    "plan",
    "zones",
    "extendedLocation",
  ]
  response_export_values = ["properties.vmId", "properties.storageProfile.osDisk.managedDisk.id", "identity"]
  retry                  = var.retry
  sensitive_body         = local.linux_vm_sensitive_body
  tags                   = local.tags

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
      condition     = var.os_managed_disk_id == null || var.os_disk.diff_disk_settings == null
      error_message = "The os_managed_disk_id and os_disk.diff_disk_settings are mutually exclusive. Ephemeral OS disks cannot be used when attaching an existing managed disk."
    }
    precondition {
      condition     = local.parent_id_for_resource_group[var.resource_group_name] != null
      error_message = "Unable to determine the subscription for the virtual machine. Set `parent_id` to the resource group resource ID, or supply `private_ip_subnet_resource_id` on at least one IP configuration so the subscription can be derived from it."
    }
    # ARM keys a data disk by its lun, so two disks sharing one would silently collapse into a
    # single entry rather than failing.
    precondition {
      condition     = length(local.vm_data_disks) == length(distinct([for disk in local.vm_data_disks : disk.lun]))
      error_message = "Each data disk needs its own lun, across both `data_disk_managed_disks` and `data_disk_existing_disks`."
    }
  }
  depends_on = [ #the associations are now properties of the interface body, so the interface alone is enough.
    azapi_resource.virtualmachine_network_interfaces
  ]
}

moved {
  from = azurerm_management_lock.this-linux-virtualmachine
  to   = azurerm_management_lock.this_linux_virtualmachine
}

moved {
  from = azurerm_management_lock.this_linux_virtualmachine
  to   = azapi_resource.this_linux_virtualmachine_lock
}

#set explicit dependencies on all the child resources to ensure that they have finished update and modification prior to locking the vm
resource "azapi_resource" "this_linux_virtualmachine_lock" {
  count = (var.lock != null) && !(lower(var.os_type) == "windows") ? 1 : 0

  name      = coalesce(var.lock.name, "lock-${var.lock.kind}")
  parent_id = azapi_resource.this_linux_virtual_machine[0].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.lock.kind
      notes = local.interface_lock_notes[var.lock.kind]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

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
    azapi_resource.this_data_disk,
    azapi_resource.virtualmachine_network_interfaces,
    azapi_resource.virtualmachine_public_ips,
    azapi_resource.system_managed_identity_role_assignments,
    azapi_resource.this_linux_virtual_machine,
    azapi_resource.this_network_interface_diagnostic_settings,
    azapi_resource.this_virtual_machine_diagnostic_settings,
    module.extension,
    module.extension_1,
    module.extension_2,
    module.run_command,
    module.run_command_1,
    module.run_command_2
  ]
}
