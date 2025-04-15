resource "azurerm_virtual_machine_extension" "this" {
  name                        = var.name
  publisher                   = var.publisher
  type                        = var.type
  type_handler_version        = var.type_handler_version
  virtual_machine_id          = var.virtualmachine_resource_id
  auto_upgrade_minor_version  = var.auto_upgrade_minor_version
  automatic_upgrade_enabled   = var.automatic_upgrade_enabled
  failure_suppression_enabled = var.failure_suppression_enabled
  protected_settings          = var.protected_settings
  provision_after_extensions  = var.provision_after_extensions
  settings                    = var.settings
  tags                        = var.tags

  dynamic "protected_settings_from_key_vault" {
    for_each = var.protected_settings_from_key_vault != null ? [var.protected_settings_from_key_vault] : []

    content {
      secret_url      = var.protected_settings_from_key_vault.secret_url
      source_vault_id = var.protected_settings_from_key_vault.source_vault_id
    }
  }
  timeouts {
    create = var.timeouts.create
    delete = var.timeouts.delete
    read   = var.timeouts.read
    update = var.timeouts.update
  }
}
