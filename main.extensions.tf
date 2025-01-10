module "extension" {
  source = "./modules/extension"

  for_each = toset([for k, v in nonsensitive(var.extensions) : k if v.deploy_sequence >= 3]) #forcing to use the map key to address terraform limitation around sensitive values in the map (https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#limitations-on-values-used-in-for_each)

  #using explicit references using the for_each key to get around the secrets issue in the above link
  name                              = var.extensions[each.key].name
  publisher                         = var.extensions[each.key].publisher
  type                              = var.extensions[each.key].type
  type_handler_version              = var.extensions[each.key].type_handler_version
  virtualmachine_resource_id        = local.virtualmachine_resource_id
  auto_upgrade_minor_version        = var.extensions[each.key].auto_upgrade_minor_version
  automatic_upgrade_enabled         = var.extensions[each.key].automatic_upgrade_enabled
  failure_suppression_enabled       = var.extensions[each.key].failure_suppression_enabled
  protected_settings                = var.extensions[each.key].protected_settings
  provision_after_extensions        = var.extensions[each.key].provision_after_extensions
  settings                          = var.extensions[each.key].settings
  protected_settings_from_key_vault = var.extensions[each.key].protected_settings_from_key_vault

  timeouts = {
    create = coalesce(var.extensions[each.key].timeouts.create, var.timeouts.azurerm_virtual_machine_extension.create)
    delete = coalesce(var.extensions[each.key].timeouts.delete, var.timeouts.azurerm_virtual_machine_extension.delete)
    read   = coalesce(var.extensions[each.key].timeouts.read, var.timeouts.azurerm_virtual_machine_extension.read)
    update = coalesce(var.extensions[each.key].timeouts.update, var.timeouts.azurerm_virtual_machine_extension.update)
  }

  tags = var.extensions[each.key].tags != null && var.extensions[each.key].tags != {} ? var.extensions[each.key].tags : local.tags

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows,
    module.extension_1,
    module.extension_2
  ]
}

module "extension_1" {
  source = "./modules/extension"

  for_each = toset([for k, v in nonsensitive(var.extensions) : k if v.deploy_sequence == 1]) #forcing to use the map key to address terraform limitation around sensitive values in the map (https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#limitations-on-values-used-in-for_each)

  #using explicit references using the for_each key to get around the secrets issue in the above link
  name                              = var.extensions[each.key].name
  publisher                         = var.extensions[each.key].publisher
  type                              = var.extensions[each.key].type
  type_handler_version              = var.extensions[each.key].type_handler_version
  virtualmachine_resource_id        = local.virtualmachine_resource_id
  auto_upgrade_minor_version        = var.extensions[each.key].auto_upgrade_minor_version
  automatic_upgrade_enabled         = var.extensions[each.key].automatic_upgrade_enabled
  failure_suppression_enabled       = var.extensions[each.key].failure_suppression_enabled
  protected_settings                = var.extensions[each.key].protected_settings
  provision_after_extensions        = var.extensions[each.key].provision_after_extensions
  settings                          = var.extensions[each.key].settings
  protected_settings_from_key_vault = var.extensions[each.key].protected_settings_from_key_vault

  timeouts = {
    create = coalesce(each.value.timeouts.create, var.timeouts.azurerm_virtual_machine_extension.create)
    delete = coalesce(each.value.timeouts.delete, var.timeouts.azurerm_virtual_machine_extension.delete)
    read   = coalesce(each.value.timeouts.read, var.timeouts.azurerm_virtual_machine_extension.read)
    update = coalesce(each.value.timeouts.update, var.timeouts.azurerm_virtual_machine_extension.update)
  }

  tags = var.extensions[each.key].tags != null && var.extensions[each.key].tags != {} ? var.extensions[each.key].tags : local.tags

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows,
  ]
}

module "extension_2" {
  source = "./modules/extension"

  for_each = toset([for k, v in nonsensitive(var.extensions) : k if v.deploy_sequence == 2]) #forcing to use the map key to address terraform limitation around sensitive values in the map (https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#limitations-on-values-used-in-for_each)

  #using explicit references using the for_each key to get around the secrets issue in the above link
  name                              = var.extensions[each.key].name
  publisher                         = var.extensions[each.key].publisher
  type                              = var.extensions[each.key].type
  type_handler_version              = var.extensions[each.key].type_handler_version
  virtualmachine_resource_id        = local.virtualmachine_resource_id
  auto_upgrade_minor_version        = var.extensions[each.key].auto_upgrade_minor_version
  automatic_upgrade_enabled         = var.extensions[each.key].automatic_upgrade_enabled
  failure_suppression_enabled       = var.extensions[each.key].failure_suppression_enabled
  protected_settings                = var.extensions[each.key].protected_settings
  provision_after_extensions        = var.extensions[each.key].provision_after_extensions
  settings                          = var.extensions[each.key].settings
  protected_settings_from_key_vault = var.extensions[each.key].protected_settings_from_key_vault

  timeouts = {
    create = coalesce(each.value.timeouts.create, var.timeouts.azurerm_virtual_machine_extension.create)
    delete = coalesce(each.value.timeouts.delete, var.timeouts.azurerm_virtual_machine_extension.delete)
    read   = coalesce(each.value.timeouts.read, var.timeouts.azurerm_virtual_machine_extension.read)
    update = coalesce(each.value.timeouts.update, var.timeouts.azurerm_virtual_machine_extension.update)
  }

  tags = var.extensions[each.key].tags != null && var.extensions[each.key].tags != {} ? var.extensions[each.key].tags : local.tags

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows,
    module.extension_1
  ]
}
