moved {
  from = azurerm_dev_test_global_vm_shutdown_schedule.this
  to   = azapi_resource.this_shutdown_schedule
}

resource "azapi_resource" "this_shutdown_schedule" {
  for_each = var.shutdown_schedules

  # Azure returns a 400 for a compute VM shutdown schedule under any other name, and the schedule is
  # parented to the machine's resource group rather than to the machine. Both reproduce the
  # identifier the azurerm provider generated, so the moved block above adopts the existing schedule
  # in place instead of destroying and recreating it.
  location  = var.location
  name      = "shutdown-computevm-${var.name}"
  parent_id = local.parent_id_for_resource_group[var.resource_group_name]
  type      = var.resource_types.devtestlab_schedules
  body = {
    properties = {
      status   = each.value.enabled ? "Enabled" : "Disabled"
      taskType = "ComputeVmShutdownTask"
      dailyRecurrence = {
        time = each.value.daily_recurrence_time
      }
      timeZoneId       = each.value.timezone
      targetResourceId = local.virtualmachine_resource_id
      notificationSettings = {
        status = each.value.notification_settings.enabled ? "Enabled" : "Disabled"
        # The input is a string because that is the shape the module has always accepted; ARM types
        # this as an integer.
        timeInMinutes  = tonumber(each.value.notification_settings.time_in_minutes)
        emailRecipient = each.value.notification_settings.email
        webhookUrl     = each.value.notification_settings.webhook_url
      }
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.devtestlab_schedules) > 0 ? var.ignore_body_changes.devtestlab_schedules : null
  # An unset email or webhook must be absent from the request rather than sent as an explicit null.
  ignore_null_property = true
  replace_triggers_refs = [
    # virtual_machine_id was ForceNew under the azurerm provider: Azure cannot retarget an existing
    # schedule at a different machine.
    "properties.targetResourceId",
  ]
  response_export_values = []
  retry                  = var.retry
  tags                   = each.value.tags

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
    azapi_resource.this_linux_virtual_machine,
    azapi_resource.this_windows_virtual_machine
  ]
}
