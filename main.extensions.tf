resource "azurerm_virtual_machine_extension" "this_extension" {
  for_each = toset([for k, v in nonsensitive(var.extensions) : k]) #forcing to use the map key to address terraform limitation around sensitive values in the map (https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#limitations-on-values-used-in-for_each)

  #using explicit references using the for_each key to get around the secrets issue in the above link
  name                        = var.extensions[each.key].name
  publisher                   = var.extensions[each.key].publisher
  type                        = var.extensions[each.key].type
  type_handler_version        = var.extensions[each.key].type_handler_version
  virtual_machine_id          = local.virtualmachine_resource_id
  auto_upgrade_minor_version  = var.extensions[each.key].auto_upgrade_minor_version
  automatic_upgrade_enabled   = var.extensions[each.key].automatic_upgrade_enabled
  failure_suppression_enabled = var.extensions[each.key].failure_suppression_enabled
  protected_settings          = var.extensions[each.key].protected_settings
  provision_after_extensions  = var.extensions[each.key].provision_after_extensions
  settings                    = var.extensions[each.key].settings
  tags                        = var.extensions[each.key].tags != null && var.extensions[each.key].tags != {} ? var.extensions[each.key].tags : local.tags

  dynamic "protected_settings_from_key_vault" {
    for_each = var.extensions[each.key].protected_settings_from_key_vault != null ? [each.key] : []

    content {
      secret_url      = var.extensions[each.key].protected_settings_from_key_vault.secret_url
      source_vault_id = var.extensions[each.key].protected_settings_from_key_vault.source_vault_id
    }
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}
