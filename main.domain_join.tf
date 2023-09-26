#get the domain join user password from a key vault if a vault and secret are specified
data "azurerm_key_vault_secret" "domain_join_user_password" {
  count        = var.domain_join_extension_values.domain_join_user_key_vault_resource_id != null && var.domain_join_extension_values.domain_join_user_key_vault_secret_name != null ? 1 : 0
  name         = var.domain_join_extension_values.domain_join_user_key_vault_secret_name
  key_vault_id = var.domain_join_extension_values.domain_join_user_key_vault_resource_id
}

#deploy the domain join extension resource
resource "azurerm_virtual_machine_extension" "domain_join" {
  count = var.domain_join_the_windows_vm ? 1 : 0
  name                       = var.virtualmachine_name
  virtual_machine_id         = local.virtualmachine_resource_id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  settings                   = jsonencode(local.domain_join_extension_settings)
  protected_settings         = jsonencode(local.domain_join_extension_protected_settings)
  tags                       = var.tags
}
