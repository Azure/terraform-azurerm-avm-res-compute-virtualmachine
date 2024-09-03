#create public ip(s) - Assumes each ip configuration has a unique name
resource "azurerm_public_ip" "virtualmachine_public_ips" {
  for_each = { for key, values in local.nics_ip_configs : key => values if values.ipconfig.create_public_ip_address == true }

  allocation_method       = var.public_ip_configuration_details.allocation_method
  location                = var.location
  name                    = each.value.ipconfig.public_ip_address_name
  resource_group_name     = var.resource_group_name
  ddos_protection_mode    = var.public_ip_configuration_details.ddos_protection_mode
  ddos_protection_plan_id = var.public_ip_configuration_details.ddos_protection_plan_id
  domain_name_label       = var.public_ip_configuration_details.domain_name_label
  edge_zone               = var.edge_zone #var.public_ip_configuration_details.edge_zone
  idle_timeout_in_minutes = var.public_ip_configuration_details.idle_timeout_in_minutes
  ip_version              = var.public_ip_configuration_details.ip_version
  sku                     = var.public_ip_configuration_details.sku
  sku_tier                = var.public_ip_configuration_details.sku_tier
  tags                    = var.public_ip_configuration_details.tags != null && var.public_ip_configuration_details != {} ? var.public_ip_configuration_details.tags : local.tags
  zones                   = var.zone != null ? [var.zone] : [] #var.public_ip_configuration_details.zones
}


#create the Nics
resource "azurerm_network_interface" "virtualmachine_network_interfaces" {
  for_each = var.network_interfaces

  location                       = var.location
  name                           = each.value.name
  resource_group_name            = coalesce(each.value.resource_group_name, var.resource_group_name)
  accelerated_networking_enabled = each.value.accelerated_networking_enabled
  dns_servers                    = each.value.dns_servers
  edge_zone                      = var.edge_zone #each.value.edge_zone
  internal_dns_name_label        = each.value.internal_dns_name_label
  ip_forwarding_enabled          = each.value.ip_forwarding_enabled
  tags                           = each.value.tags != null && each.value.tags != {} ? each.value.tags : local.tags

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name                                               = ip_configuration.value.name
      private_ip_address_allocation                      = ip_configuration.value.private_ip_address_allocation
      gateway_load_balancer_frontend_ip_configuration_id = ip_configuration.value.gateway_load_balancer_frontend_ip_configuration_resource_id
      primary                                            = ip_configuration.value.is_primary_ipconfiguration
      private_ip_address                                 = ip_configuration.value.private_ip_address
      private_ip_address_version                         = ip_configuration.value.private_ip_address_version
      public_ip_address_id                               = ip_configuration.value.create_public_ip_address ? azurerm_public_ip.virtualmachine_public_ips["${each.key}-${ip_configuration.key}"].id : ip_configuration.value.public_ip_address_resource_id
      subnet_id                                          = ip_configuration.value.private_ip_subnet_resource_id
    }
  }
}

#configure locks on each public IP that has been created if lock values are set.  
resource "azurerm_management_lock" "this_public_ip" {
  for_each = { for key, values in local.nics_ip_configs : key => values if((values.ipconfig.create_public_ip_address == true) && (var.public_ip_configuration_details.lock_level != null)) }

  lock_level = var.public_ip_configuration_details.lock_level
  name       = coalesce(each.value.ipconfig.public_ip_address_lock_name, "${each.key}-lock")
  scope      = azurerm_public_ip.virtualmachine_public_ips[each.key].id

  depends_on = [
    azurerm_network_interface.virtualmachine_network_interfaces,
    azurerm_public_ip.virtualmachine_public_ips,
    azurerm_linux_virtual_machine.this,
    azurerm_windows_virtual_machine.this
  ]
}

#configure resource locks on each NIC if the lock values are set
resource "azurerm_management_lock" "this_nic" {
  for_each = { for nic, nicvalues in var.network_interfaces : nic => nicvalues if nicvalues.lock_level != null }

  lock_level = each.value.lock_level
  name       = coalesce(each.value.lock_name, "${each.key}-lock")
  scope      = azurerm_network_interface.virtualmachine_network_interfaces[each.key].id

  depends_on = [
    azurerm_network_interface.virtualmachine_network_interfaces,
    azurerm_public_ip.virtualmachine_public_ips,
    azurerm_linux_virtual_machine.this,
    azurerm_windows_virtual_machine.this
  ]
}

#assign permissions to the network interface and/or public ip if enabled and role assignments included
resource "azurerm_role_assignment" "this_network_interface" {
  for_each = local.nics_role_assignments

  principal_id                           = each.value.role_assignment.principal_id
  scope                                  = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
  condition                              = each.value.role_assignment.condition
  condition_version                      = each.value.role_assignment.condition_version
  delegated_managed_identity_resource_id = each.value.role_assignment.delegated_managed_identity_resource_id
  principal_type                         = each.value.role_assignment.principal_type
  role_definition_id                     = (length(split("/", each.value.role_assignment.role_definition_id_or_name))) > 3 ? each.value.role_assignment.role_definition_id_or_name : null
  role_definition_name                   = (length(split("/", each.value.role_assignment.role_definition_id_or_name))) > 3 ? null : each.value.role_assignment.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.role_assignment.skip_service_principal_aad_check
}

resource "azurerm_monitor_diagnostic_setting" "this_nic_diags" {
  for_each = local.nics_diag_settings

  name                           = each.value.diagnostic_setting.name
  target_resource_id             = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
  eventhub_authorization_rule_id = each.value.diagnostic_setting.event_hub_authorization_rule_resource_id
  log_analytics_destination_type = each.value.diagnostic_setting.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.diagnostic_setting.workspace_resource_id
  partner_solution_id            = each.value.diagnostic_setting.marketplace_partner_resource_id
  storage_account_id             = each.value.diagnostic_setting.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.diagnostic_setting.log_categories

    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.diagnostic_setting.log_groups

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.diagnostic_setting.metric_categories

    content {
      category = metric.value
    }
  }
}

#create the nic associations
### NSG associations
resource "azurerm_network_interface_security_group_association" "this" {
  for_each = local.nics_nsgs

  network_interface_id      = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
  network_security_group_id = each.value.network_security_groups.network_security_group_resource_id
}

### ASG Associations 
resource "azurerm_network_interface_application_security_group_association" "this" {
  for_each = local.nics_asgs

  application_security_group_id = each.value.application_security_groups.application_security_group_resource_id
  network_interface_id          = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
}


### LB Pool Association
resource "azurerm_network_interface_backend_address_pool_association" "this" {
  for_each = local.nics_ip_configs_lb_pools

  backend_address_pool_id = each.value.lb_pools.load_balancer_backend_pool_resource_id
  ip_configuration_name   = each.value.ipconfig_name
  network_interface_id    = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
}

### App GW Assocation
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "this" {
  for_each = local.nics_ip_configs_app_gw_pools

  backend_address_pool_id = each.value.ag_pools.app_gateway_backend_pool_resource_id
  ip_configuration_name   = each.value.ipconfig_name
  network_interface_id    = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
}

### NAT Rule Assocation
resource "azurerm_network_interface_nat_rule_association" "this" {
  for_each = local.nics_ip_configs_lb_nat_rules

  ip_configuration_name = each.value.ipconfig_name
  nat_rule_id           = each.value.lb_nat_rules.load_balancer_nat_rule_resource_id
  network_interface_id  = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
}
