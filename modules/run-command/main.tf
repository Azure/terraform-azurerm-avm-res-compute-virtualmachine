moved {
  from = azurerm_virtual_machine_run_command.this
  to   = azapi_resource.this
}

# A stopped VM rejects run command operations. `action_trigger` needs a static action reference, so
# the action always exists: it starts the VM when enabled and otherwise issues a read-only GET that
# changes nothing.
action "azapi_resource_action" "start_virtual_machine" {
  config {
    resource_id = coalesce(var.start_virtual_machine_resource_id, var.virtualmachine_resource_id)
    type        = var.virtual_machine_resource_type
    action      = var.start_virtual_machine_before_change ? "start" : null
    method      = var.start_virtual_machine_before_change ? "POST" : "GET"
  }
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.virtualmachine_resource_id
  type      = var.resource_types.compute_virtual_machines_run_commands
  body = {
    properties = local.run_command_properties
  }
  ignore_body_changes = length(var.ignore_body_changes.compute_virtual_machines_run_commands) > 0 ? var.ignore_body_changes.compute_virtual_machines_run_commands : null
  # No `replace_triggers_refs`: the only arguments the azurerm provider marked ForceNew were `name`,
  # `location` and the parent virtual machine, and AzAPI already forces replacement on all three.
  response_export_values = []
  retry                  = var.retry
  sensitive_body         = local.run_command_sensitive_body
  sensitive_body_version = local.run_command_sensitive_body_version
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
      events  = [before_create, before_update, before_destroy]
      actions = [action.azapi_resource_action.start_virtual_machine]
    }
  }
}
