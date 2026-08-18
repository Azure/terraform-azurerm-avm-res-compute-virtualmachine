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
}
