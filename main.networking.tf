moved {
  from = azurerm_public_ip.virtualmachine_public_ips
  to   = azapi_resource.virtualmachine_public_ips
}

#create public ip(s) - Assumes each ip configuration has a unique name
resource "azapi_resource" "virtualmachine_public_ips" {
  for_each = { for key, values in local.nics_ip_configs : key => values if values.ipconfig.create_public_ip_address == true }

  location               = var.location
  name                   = each.value.ipconfig.public_ip_address_name
  parent_id              = local.public_ip_parent_id
  type                   = var.resource_types.network_public_ip_addresses
  body                   = local.public_ip_body
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes    = length(var.ignore_body_changes.network_public_ip_addresses) > 0 ? var.ignore_body_changes.network_public_ip_addresses : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = ["properties.ipAddress", "properties.dnsSettings"]
  retry                  = var.retry
  tags                   = var.public_ip_configuration_details.tags != null ? var.public_ip_configuration_details.tags : local.tags
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
      condition     = local.public_ip_parent_id != null
      error_message = "Unable to determine the subscription for the public IP address. Set `parent_id` to the resource group resource ID, or supply `private_ip_subnet_resource_id` on at least one IP configuration so the subscription can be derived from it."
    }
  }
}

moved {
  from = azurerm_network_interface.virtualmachine_network_interfaces
  to   = azapi_resource.virtualmachine_network_interfaces
}

#create the Nics
resource "azapi_resource" "virtualmachine_network_interfaces" {
  for_each = var.network_interfaces

  location               = var.location
  name                   = each.value.name
  parent_id              = local.nic_parent_ids[each.key]
  type                   = var.resource_types.network_network_interfaces
  body                   = local.nic_bodies[each.key]
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes    = length(var.ignore_body_changes.network_network_interfaces) > 0 ? var.ignore_body_changes.network_network_interfaces : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = ["properties.ipConfigurations", "properties.macAddress", "properties.virtualMachine", "properties.dnsSettings"]
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
      condition     = local.nic_parent_ids[each.key] != null
      error_message = "Unable to determine the subscription for network interface '${each.key}'. Set `parent_id` to the resource group resource ID, or supply `private_ip_subnet_resource_id` on at least one IP configuration so the subscription can be derived from it."
    }
    precondition {
      condition     = length(each.value.network_security_groups) <= 1
      error_message = "Network interface '${each.key}' declares ${length(each.value.network_security_groups)} network security groups. ARM attaches at most one network security group to an interface, so only a single entry is supported."
    }
  }
}

moved {
  from = azurerm_management_lock.this_public_ip
  to   = azapi_resource.this_public_ip_lock
}

#configure locks on each public IP that has been created if lock values are set.
resource "azapi_resource" "this_public_ip_lock" {
  for_each = { for key, values in local.nics_ip_configs : key => values if((values.ipconfig.create_public_ip_address == true) && (var.public_ip_configuration_details.lock_level != null)) }

  name      = coalesce(each.value.ipconfig.public_ip_address_lock_name, "${each.key}-lock")
  parent_id = azapi_resource.virtualmachine_public_ips[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.public_ip_configuration_details.lock_level
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
    azapi_resource.virtualmachine_network_interfaces,
    azapi_resource.virtualmachine_public_ips,
    azapi_resource.this_linux_virtual_machine,
    azapi_resource.this_windows_virtual_machine
  ]
}

moved {
  from = azurerm_management_lock.this_nic
  to   = azapi_resource.this_nic_lock
}

#configure resource locks on each NIC if the lock values are set
resource "azapi_resource" "this_nic_lock" {
  for_each = { for nic, nicvalues in var.network_interfaces : nic => nicvalues if nicvalues.lock_level != null }

  name      = coalesce(each.value.lock_name, "${each.key}-lock")
  parent_id = azapi_resource.virtualmachine_network_interfaces[each.key].id
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
    azapi_resource.virtualmachine_network_interfaces,
    azapi_resource.virtualmachine_public_ips,
    azapi_resource.this_linux_virtual_machine,
    azapi_resource.this_windows_virtual_machine
  ]
}

moved {
  from = azurerm_role_assignment.this_network_interface
  to   = azapi_resource.this_network_interface_role_assignments
}

#assign permissions to the network interface and/or public ip if enabled and role assignments included
resource "azapi_resource" "this_network_interface_role_assignments" {
  for_each = local.nics_role_assignments

  name                 = module.avm_utl_interfaces.role_assignments_azapi["nic-${each.key}"].name
  parent_id            = azapi_resource.virtualmachine_network_interfaces[each.value.nic_key].id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_utl_interfaces.role_assignments_azapi["nic-${each.key}"].body
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
    # See the note on azapi_resource.disks_role_assignments: the generated GUID name would force a
    # replacement, and deleting an assignment under a CanNotDelete lock fails with ScopeLocked.
    ignore_changes = [name]
  }
}

moved {
  from = azurerm_monitor_diagnostic_setting.this_nic_diags
  to   = azapi_resource.this_network_interface_diagnostic_settings
}

resource "azapi_resource" "this_network_interface_diagnostic_settings" {
  for_each = local.nics_diag_settings

  name                   = each.value.diagnostic_setting.name
  parent_id              = azapi_resource.virtualmachine_network_interfaces[each.value.nic_key].id
  type                   = var.resource_types.insights_diagnostic_settings
  body                   = local.interface_diagnostic_settings_nic[each.key]
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes    = length(var.ignore_body_changes.insights_diagnostic_settings) > 0 ? var.ignore_body_changes.insights_diagnostic_settings : null
  ignore_null_property   = true
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
}

# ARM has no standalone association resources. Every association below is a property of the network
# interface (or of one of its IP configurations) and is now assembled into the interface body by
# local.nic_bodies. Forget the previous state entries without issuing a remote delete: the interface
# itself keeps its state through the `moved` block above, so the underlying Azure configuration is
# unchanged and only Terraform's model of it differs.
#
# The map keys are user-defined, so keyed `moved` blocks cannot be generated for these addresses.
removed {
  from = azurerm_network_interface_security_group_association.this

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_network_interface_application_security_group_association.this

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_network_interface_backend_address_pool_association.this

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_network_interface_application_gateway_backend_address_pool_association.this

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_network_interface_nat_rule_association.this

  lifecycle {
    destroy = false
  }
}
