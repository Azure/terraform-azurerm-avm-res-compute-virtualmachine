# resource "azurerm_maintenance_assignment_virtual_machine" "this" {
#   for_each = var.maintenance_configuration_resource_ids
#
#   location                     = var.location
#   maintenance_configuration_id = each.value
#   virtual_machine_id           = local.virtualmachine_resource_id
#
#   depends_on = [
#     azurerm_virtual_machine_data_disk_attachment.this_linux,
#     azurerm_virtual_machine_data_disk_attachment.this_windows
#   ]
# }

resource "azapi_resource" "this_maintenance_configuration_assignment" {
  for_each = var.maintenance_configuration_resource_ids

  location  = var.location
  name      = "${var.name}-maintenance-configuration-${each.key}"
  parent_id = local.virtualmachine_resource_id
  type      = var.resource_types.maintenance_configuration_assignments
  body = {
    properties = {
      maintenanceConfigurationId = lower(each.value)
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_body_changes    = length(var.ignore_body_changes.maintenance_configuration_assignments) > 0 ? var.ignore_body_changes.maintenance_configuration_assignments : null
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

moved {
  from = azurerm_maintenance_assignment_virtual_machine.this
  to   = azapi_resource.this_maintenance_configuration_assignment
}
