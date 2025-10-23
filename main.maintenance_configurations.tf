/*
resource "azurerm_maintenance_assignment_virtual_machine" "this" {
  for_each = var.maintenance_configuration_resource_ids

  location                     = var.location
  maintenance_configuration_id = each.value
  virtual_machine_id           = local.virtualmachine_resource_id

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}
*/

resource "azapi_resource" "this_maintenance_configuration_assignment" {
  for_each = var.maintenance_configuration_resource_ids

  location  = var.location
  name      = "${var.name}-maintenance-configuration-${each.key}"
  parent_id = local.virtualmachine_resource_id
  type      = "Microsoft.Maintenance/configurationAssignments@2023-04-01"
  body = {
    properties = {
      maintenanceConfigurationId = lower(each.value)
    }
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}

moved {
  from = azurerm_maintenance_assignment_virtual_machine.this
  to   = azapi_resource.this_maintenance_configuration_assignment
}
