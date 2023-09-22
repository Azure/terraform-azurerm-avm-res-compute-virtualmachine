resource "azurerm_backup_protected_vm" "this" {
  count = var.enable_azure_backup ? 1 : 0

  resource_group_name = var.azure_backup_configuration.recovery_vault_resource_group_name
  recovery_vault_name = var.azure_backup_configuration.recovery_vault_name
  source_vm_id        = local.virtualmachine_resource_id
  backup_policy_id    = var.azure_backup_configuration.backup_policy_resource_id
  exclude_disk_luns   = var.azure_backup_configuration.exclude_disk_luns
  include_disk_luns   = var.azure_backup_configuration.include_disk_luns
  protection_state    = var.azure_backup_configuration.protection_state
}
