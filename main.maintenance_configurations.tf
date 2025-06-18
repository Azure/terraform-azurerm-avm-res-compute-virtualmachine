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
  type     = "Microsoft.Maintenance/configurationAssignments@2023-04-01"
  for_each = var.maintenance_configuration_resource_ids

  parent_id = local.virtualmachine_resource_id
  name      = "${var.name}-maintenance-configuration-${each.key}"

  location = var.location
  body = {
    properties = {
      maintenanceConfigurationId = each.value
    }
  }
}

moved {
  from = azurerm_maintenance_assignment_virtual_machine.this
  to   = azapi_resource.this_maintenance_configuration_assignment
}
