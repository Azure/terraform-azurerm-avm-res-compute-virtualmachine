resource "azurerm_virtual_machine_extension" "guest_configuration_extension" {
  count = var.azure_guest_configuration_extension.guest_config_extension_enabled ? 1 : 0

  name                       = coalesce(var.azure_guest_configuration_extension.name, "${var.virtualmachine_name}-azure-guest-configuration-extension")
  virtual_machine_id         = local.virtualmachine_resource_id
  publisher                  = "Microsoft.GuestConfiguration"
  type                       = (lower(var.virtualmachine_os_type) == "windows") ? "ConfigurationForWindows" : "ConfigurationForLinux"
  type_handler_version       = var.azure_guest_configuration_extension.type_handler_version
  auto_upgrade_minor_version = var.azure_guest_configuration_extension.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.azure_guest_configuration_extension.automatic_upgrade_enabled  
}
