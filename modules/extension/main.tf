moved {
  from = azurerm_virtual_machine_extension.this
  to   = azapi_resource.this
}

# A stopped VM rejects extension operations. `action_trigger` needs a static action reference, so
# the action is always declared. It starts the VM when enabled and otherwise issues a read-only GET
# that changes nothing. The create and update triggers are conditional, so the action is not planned
# at all unless the module is opted in.
action "azapi_resource_action" "start_virtual_machine" {
  config {
    resource_id = coalesce(var.start_virtual_machine_resource_id, var.virtualmachine_resource_id)
    type        = var.resource_types.compute_virtual_machines
    action      = var.start_virtual_machine_before_change ? "start" : null
    method      = var.start_virtual_machine_before_change ? "POST" : "GET"
  }
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

  lifecycle {
    action_trigger {
      events    = [before_create, before_update]
      condition = var.start_virtual_machine_before_change
      actions   = [action.azapi_resource_action.start_virtual_machine]
    }

    # Terraform rejects a condition on destroy events, so this always fires and falls back to a
    # read-only GET when the flag is off.
    action_trigger {
      events  = [before_destroy]
      actions = [action.azapi_resource_action.start_virtual_machine]
    }
  }
}
