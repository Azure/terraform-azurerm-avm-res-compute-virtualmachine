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