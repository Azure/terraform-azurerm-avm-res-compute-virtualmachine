resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  for_each = var.shutdown_schedules

  daily_recurrence_time = each.value.daily_recurrence_time
  location              = var.location
  timezone              = each.value.timezone
  virtual_machine_id    = local.virtualmachine_resource_id
  enabled               = each.value.enabled
  tags                  = each.value.tags

  notification_settings {
    enabled         = each.value.notification_settings.enabled
    email           = each.value.notification_settings.email
    time_in_minutes = each.value.notification_settings.time_in_minutes
    webhook_url     = each.value.notification_settings.webhook_url
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}