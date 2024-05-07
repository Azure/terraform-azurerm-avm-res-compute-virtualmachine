resource "azurerm_backup_protected_vm" "this" {
  recovery_vault_name = var.azure_backup_configurations.recovery_vault_name
  resource_group_name = coalesce(var.azure_backup_configurations.resource_group_name, var.resource_group_name)
  backup_policy_id    = var.azure_backup_configurations.backup_policy_resource_id
  exclude_disk_luns   = var.azure_backup_configurations.exclude_disk_luns
  include_disk_luns   = var.azure_backup_configurations.include_disk_luns
  protection_state    = var.azure_backup_configurations.protection_state
  source_vm_id        = local.virtualmachine_resource_id

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}