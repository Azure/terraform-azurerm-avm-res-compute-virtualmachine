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
  zones                   = var.public_ip_configuration_details.zones #var.zone != null ? [var.zone] : [] #
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

moved {
  from = azurerm_management_lock.this_public_ip
  to   = azapi_resource.this_public_ip_lock
}

#configure locks on each public IP that has been created if lock values are set.
resource "azapi_resource" "this_public_ip_lock" {
  for_each = { for key, values in local.nics_ip_configs : key => values if((values.ipconfig.create_public_ip_address == true) && (var.public_ip_configuration_details.lock_level != null)) }

  name      = coalesce(each.value.ipconfig.public_ip_address_lock_name, "${each.key}-lock")
  parent_id = azurerm_public_ip.virtualmachine_public_ips[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = var.public_ip_configuration_details.lock_level
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azurerm_network_interface.virtualmachine_network_interfaces,
    azurerm_public_ip.virtualmachine_public_ips,
    azurerm_linux_virtual_machine.this,
    azurerm_windows_virtual_machine.this
  ]
}

moved {
  from = azurerm_management_lock.this_nic
  to   = azapi_resource.this_nic_lock
}

#configure resource locks on each NIC if the lock values are set
resource "azapi_resource" "this_nic_lock" {
  for_each = { for nic, nicvalues in var.network_interfaces : nic => nicvalues if nicvalues.lock_level != null }

  name      = coalesce(each.value.lock_name, "${each.key}-lock")
  parent_id = azurerm_network_interface.virtualmachine_network_interfaces[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = {
      level = each.value.lock_level
    }
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azurerm_network_interface.virtualmachine_network_interfaces,
    azurerm_public_ip.virtualmachine_public_ips,
    azurerm_linux_virtual_machine.this,
    azurerm_windows_virtual_machine.this
  ]
}

moved {
  from = azurerm_role_assignment.this_network_interface
  to   = azapi_resource.this_network_interface_role_assignments
}

#assign permissions to the network interface and/or public ip if enabled and role assignments included
resource "azapi_resource" "this_network_interface_role_assignments" {
  for_each = local.nics_role_assignments

  name      = module.avm_utl_interfaces.role_assignments_azapi["nic-${each.key}"].name
  parent_id = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
  type      = var.resource_types.authorization_role_assignments
  body      = module.avm_utl_interfaces.role_assignments_azapi["nic-${each.key}"].body

  lifecycle {
    # See the note on azapi_resource.disks_role_assignments: the generated GUID name would force a
    # replacement, and deleting an assignment under a CanNotDelete lock fails with ScopeLocked.
    ignore_changes = [name]
  }
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_null_property   = true
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

moved {
  from = azurerm_monitor_diagnostic_setting.this_nic_diags
  to   = azapi_resource.this_nic_diags
}

resource "azapi_resource" "this_nic_diags" {
  for_each = local.nics_diag_settings

  name                   = each.value.diagnostic_setting.name
  parent_id              = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id
  type                   = var.resource_types.insights_diagnostic_settings
  body                   = local.interface_diagnostic_settings_nic[each.key]
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_null_property   = true
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  replace_triggers_refs  = []
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
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

  depends_on = [azurerm_network_interface_security_group_association.this]
}

### LB Pool Association
resource "azurerm_network_interface_backend_address_pool_association" "this" {
  for_each = local.nics_ip_configs_lb_pools

  backend_address_pool_id = each.value.lb_pools.load_balancer_backend_pool_resource_id
  ip_configuration_name   = each.value.ipconfig_name
  network_interface_id    = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id

  depends_on = [azurerm_network_interface_security_group_association.this,
  azurerm_network_interface_application_security_group_association.this]
}

### App GW Assocation
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "this" {
  for_each = local.nics_ip_configs_app_gw_pools

  backend_address_pool_id = each.value.ag_pools.app_gateway_backend_pool_resource_id
  ip_configuration_name   = each.value.ipconfig_name
  network_interface_id    = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id

  timeouts {
    delete = "60m"
  }

  depends_on = [azurerm_network_interface_security_group_association.this,
    azurerm_network_interface_application_security_group_association.this,
  azurerm_network_interface_backend_address_pool_association.this]
}

### NAT Rule Assocation
resource "azurerm_network_interface_nat_rule_association" "this" {
  for_each = local.nics_ip_configs_lb_nat_rules

  ip_configuration_name = each.value.ipconfig_name
  nat_rule_id           = each.value.lb_nat_rules.load_balancer_nat_rule_resource_id
  network_interface_id  = azurerm_network_interface.virtualmachine_network_interfaces[each.value.nic_key].id

  depends_on = [azurerm_network_interface_security_group_association.this,
    azurerm_network_interface_application_security_group_association.this,
    azurerm_network_interface_backend_address_pool_association.this,
  azurerm_network_interface_application_gateway_backend_address_pool_association.this]
}
