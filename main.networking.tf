#create public ip(s)
resource "azurerm_public_ip" "virtualmachine_public_ips" {
  for_each = { for pub_ip in local.flattened_nics : pub_ip.ip_config_name => pub_ip if pub_ip.create_public_ip_address }

  name                    = "${each.value.ip_config_name}-pip"
  resource_group_name     = data.azurerm_resource_group.virtualmachine_deployment.name
  location                = data.azurerm_resource_group.virtualmachine_deployment.location
  allocation_method       = var.public_ip_configuration_details.allocation_method
  zones                   = var.public_ip_configuration_details.zones
  ddos_protection_mode    = var.public_ip_configuration_details.ddos_protection_mode
  ddos_protection_plan_id = var.public_ip_configuration_details.ddos_protection_plan_id
  domain_name_label       = var.public_ip_configuration_details.domain_name_label
  edge_zone               = var.public_ip_configuration_details.edge_zone
  idle_timeout_in_minutes = var.public_ip_configuration_details.idle_timeout_in_minutes
  ip_version              = var.public_ip_configuration_details.ip_version
  sku_tier                = var.public_ip_configuration_details.sku_tier
  tags                    = var.public_ip_configuration_details.tags
}


#create the Nics
resource "azurerm_network_interface" "virtualmachine_network_interfaces" {
  for_each                      = { for nic in var.network_interfaces : nic.name => nic }
  name                          = each.value.name
  location                      = data.azurerm_resource_group.virtualmachine_deployment.location
  resource_group_name           = data.azurerm_resource_group.virtualmachine_deployment.name
  dns_servers                   = each.value.dns_servers
  edge_zone                     = each.value.edge_zone
  enable_accelerated_networking = each.value.accelerated_networking_enabled
  enable_ip_forwarding          = each.value.ip_forwarding_enabled
  internal_dns_name_label       = each.value.internal_dns_name_label
  tags                          = each.value.tags


  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations
    content {
      name                                               = ip_configuration.value.name
      gateway_load_balancer_frontend_ip_configuration_id = ip_configuration.value.gateway_load_balancer_frontend_ip_configuration_resource_id
      subnet_id                                          = ip_configuration.value.private_ip_subnet_resource_id
      private_ip_address_version                         = ip_configuration.value.private_ip_address_version
      private_ip_address_allocation                      = ip_configuration.value.private_ip_address_allocation
      public_ip_address_id                               = ip_configuration.value.create_public_ip_address ? azurerm_public_ip.virtualmachine_public_ips[ip_configuration.value.name].id : ip_configuration.value.public_ip_address_resource_id
      primary                                            = ip_configuration.value.is_primary_ipconfiguration
      private_ip_address                                 = ip_configuration.value.private_ip_address

    }
  }
}
