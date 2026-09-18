moved {
  from = azurerm_virtual_machine_extension.this
  to   = azapi_resource.this
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.virtualmachine_resource_id
  type      = var.resource_types.compute_virtual_machines_extensions
  body = {
    properties = local.extension_properties
  }
  ignore_body_changes = length(var.ignore_body_changes.compute_virtual_machines_extensions) > 0 ? var.ignore_body_changes.compute_virtual_machines_extensions : null
  # `publisher` is the only body member the azurerm provider marked ForceNew. The extension name and
  # its parent virtual machine are already force-new under AzAPI, and neither `type` nor
  # `type_handler_version` was ForceNew. Without this an immutable edit would plan as an in-place
  # update and then be rejected at apply.
  replace_triggers_refs  = ["properties.publisher"]
  response_export_values = []
  retry                  = var.retry
  sensitive_body         = local.extension_sensitive_body
  sensitive_body_version = local.extension_sensitive_body_version
  tags                   = var.tags

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
