moved {
  from = azurerm_monitor_diagnostic_setting.this_vm_diags
  to   = azapi_resource.this_virtual_machine_diagnostic_settings
}

resource "azapi_resource" "this_virtual_machine_diagnostic_settings" {
  for_each = var.diagnostic_settings

  name                   = each.value.name
  parent_id              = local.virtualmachine_resource_id
  type                   = var.resource_types.insights_diagnostic_settings
  body                   = local.interface_diagnostic_settings_vm[each.key]
  ignore_body_changes    = length(var.ignore_body_changes.insights_diagnostic_settings) > 0 ? var.ignore_body_changes.insights_diagnostic_settings : null
  ignore_null_property   = true
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
}
