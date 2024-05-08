resource "azurerm_backup_protected_vm" "this" {
  for_each = var.azure_backup_configurations

  recovery_vault_name = each.value.recovery_vault_name
  resource_group_name = coalesce(each.value.resource_group_name, var.resource_group_name)
  backup_policy_id    = each.value.backup_policy_resource_id
  exclude_disk_luns   = each.value.exclude_disk_luns
  include_disk_luns   = each.value.include_disk_luns
  protection_state    = each.value.protection_state
  source_vm_id        = local.virtualmachine_resource_id

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}