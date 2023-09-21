resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  count = var.azure_monitor_agent_enabled ? 1 : 0

  name                       = coalesce(var.azure_monitor_agent_extension_settings.name, "${var.virtualmachine_name}-azure-monitor-agent")
  virtual_machine_id         = local.virtualmachine_resource_id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = (lower(var.virtualmachine_os_type) == "windows") ? "AzureMonitorWindowsAgent" : "AzureMonitorLinuxAgent"
  type_handler_version       = var.azure_monitor_agent_extension_settings.type_handler_version
  auto_upgrade_minor_version = var.azure_monitor_agent_extension_settings.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.azure_monitor_agent_extension_settings.automatic_upgrade_enabled
  settings                   = var.azure_monitor_agent_extension_settings.managed_identity_type == "UserAssigned" ? jsonencode(local.azure_monitor_agent_authentication_user_assigned_identity_settings) : null
}

# associate to a Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "this_endpoint" {
  for_each = { for association in var.azure_monitor_data_collection_rule_associations : association.name => association }

  name                    = each.value.name
  target_resource_id      = local.virtualmachine_resource_id
  data_collection_rule_id = each.value.data_collection_rule_resource_id
  description             = each.value.description
}

# associate to a Data Collection Endpoint
resource "azurerm_monitor_data_collection_rule_association" "this" {
  for_each = { for association in var.azure_monitor_data_collection_endpoint_associations : association.name => association }

  target_resource_id          = local.virtualmachine_resource_id
  data_collection_endpoint_id = each.value.data_collection_endpoint_resource_id
  description                 = each.value.description
}
