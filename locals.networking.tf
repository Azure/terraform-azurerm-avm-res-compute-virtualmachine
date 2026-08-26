locals {
  # ARM parents the interface and its public IP to a resource group. The subscription is resolved
  # once in locals.parent.tf; see the comment there for why a data source is never used.
  nic_parent_ids = {
    for nk, nv in var.network_interfaces :
    nk => nv.resource_group_name == null && var.parent_id != null ? var.parent_id : (
      local.parent_id_for_resource_group[coalesce(nv.resource_group_name, var.resource_group_name)]
    )
  }
  public_ip_parent_id = var.parent_id != null ? var.parent_id : local.parent_id_for_resource_group[var.resource_group_name]

  # D4: ARM models the network security group as a single reference on the interface, not a
  # collection, so at most one entry of the map can ever apply. A precondition rejects more than
  # one rather than silently discarding the rest.
  nic_network_security_group = {
    for nk, nv in var.network_interfaces :
    nk => length(nv.network_security_groups) == 0 ? null : {
      id = values(nv.network_security_groups)[0].network_security_group_resource_id
    }
  }
  # ARM scopes application security groups to each IP configuration, while the azurerm association
  # resource scoped them to the whole interface. Replicating the interface-level map onto every IP
  # configuration preserves the previous behaviour.
  nic_application_security_groups = {
    for nk, nv in var.network_interfaces :
    nk => [for ask, asv in nv.application_security_groups : { id = asv.application_security_group_resource_id }]
  }
  nic_public_ip_ids = {
    for key, values in local.nics_ip_configs :
    key => values.ipconfig.create_public_ip_address ? azapi_resource.virtualmachine_public_ips[key].id : values.ipconfig.public_ip_address_resource_id
  }
  nic_ip_configurations = {
    for nk, nv in var.network_interfaces :
    nk => [
      for ipck, ipcv in nv.ip_configurations : {
        name = ipcv.name
        properties = merge(
          {
            primary                   = ipcv.is_primary_ipconfiguration
            privateIPAddressVersion   = ipcv.private_ip_address_version
            privateIPAllocationMethod = ipcv.private_ip_address_allocation
          },
          ipcv.private_ip_address == null ? {} : { privateIPAddress = ipcv.private_ip_address },
          ipcv.private_ip_subnet_resource_id == null ? {} : { subnet = { id = ipcv.private_ip_subnet_resource_id } },
          ipcv.gateway_load_balancer_frontend_ip_configuration_resource_id == null ? {} : {
            gatewayLoadBalancer = { id = ipcv.gateway_load_balancer_frontend_ip_configuration_resource_id }
          },
          local.nic_public_ip_ids["${nk}-${ipck}"] == null ? {} : {
            publicIPAddress = { id = local.nic_public_ip_ids["${nk}-${ipck}"] }
          },
          length(local.nic_application_security_groups[nk]) == 0 ? {} : {
            applicationSecurityGroups = local.nic_application_security_groups[nk]
          },
          length(ipcv.load_balancer_backend_pools) == 0 ? {} : {
            loadBalancerBackendAddressPools = [
              for lbk, lbv in ipcv.load_balancer_backend_pools : { id = lbv.load_balancer_backend_pool_resource_id }
            ]
          },
          length(ipcv.app_gateway_backend_pools) == 0 ? {} : {
            applicationGatewayBackendAddressPools = [
              for agk, agv in ipcv.app_gateway_backend_pools : { id = agv.app_gateway_backend_pool_resource_id }
            ]
          },
          length(ipcv.load_balancer_nat_rules) == 0 ? {} : {
            loadBalancerInboundNatRules = [
              for lbk, lbv in ipcv.load_balancer_nat_rules : { id = lbv.load_balancer_nat_rule_resource_id }
            ]
          },
        )
      }
    ]
  }
  nic_dns_settings = {
    for nk, nv in var.network_interfaces :
    nk => nv.dns_servers == null && nv.internal_dns_name_label == null ? null : merge(
      nv.dns_servers == null ? {} : { dnsServers = nv.dns_servers },
      nv.internal_dns_name_label == null ? {} : { internalDnsNameLabel = nv.internal_dns_name_label },
    )
  }
  nic_bodies = {
    for nk, nv in var.network_interfaces :
    nk => merge(
      {
        properties = merge(
          {
            enableAcceleratedNetworking = nv.accelerated_networking_enabled
            enableIPForwarding          = nv.ip_forwarding_enabled
            ipConfigurations            = local.nic_ip_configurations[nk]
          },
          local.nic_dns_settings[nk] == null ? {} : { dnsSettings = local.nic_dns_settings[nk] },
          local.nic_network_security_group[nk] == null ? {} : { networkSecurityGroup = local.nic_network_security_group[nk] },
        )
      },
      var.edge_zone == null ? {} : { extendedLocation = { name = var.edge_zone, type = "EdgeZone" } },
    )
  }

  public_ip_ddos_settings = var.public_ip_configuration_details.ddos_protection_mode == null ? null : merge(
    { protectionMode = var.public_ip_configuration_details.ddos_protection_mode },
    var.public_ip_configuration_details.ddos_protection_plan_id == null ? {} : {
      ddosProtectionPlan = { id = var.public_ip_configuration_details.ddos_protection_plan_id }
    },
  )
  public_ip_body = merge(
    {
      properties = merge(
        {
          publicIPAllocationMethod = var.public_ip_configuration_details.allocation_method
          publicIPAddressVersion   = var.public_ip_configuration_details.ip_version
          idleTimeoutInMinutes     = var.public_ip_configuration_details.idle_timeout_in_minutes
        },
        var.public_ip_configuration_details.domain_name_label == null ? {} : {
          dnsSettings = { domainNameLabel = var.public_ip_configuration_details.domain_name_label }
        },
        local.public_ip_ddos_settings == null ? {} : { ddosSettings = local.public_ip_ddos_settings },
      )
      sku = {
        name = var.public_ip_configuration_details.sku
        tier = var.public_ip_configuration_details.sku_tier
      }
    },
    var.public_ip_configuration_details.zones == null ? {} : { zones = sort(tolist(var.public_ip_configuration_details.zones)) },
    var.edge_zone == null ? {} : { extendedLocation = { name = var.edge_zone, type = "EdgeZone" } },
  )
}

# D2: the AzAPI resources expose the ARM schema, which is not what consumers of this module have
# been reading. These locals reshape each resource back into the attribute names the azurerm
# resources exported so existing expressions keep working. The unshaped objects remain available
# through the *_azapi outputs.
locals {
  network_interfaces_output = {
    for nk, nic in azapi_resource.virtualmachine_network_interfaces : nk => {
      id                             = nic.id
      name                           = nic.name
      location                       = nic.location
      resource_group_name            = coalesce(var.network_interfaces[nk].resource_group_name, var.resource_group_name)
      tags                           = nic.tags
      accelerated_networking_enabled = var.network_interfaces[nk].accelerated_networking_enabled
      ip_forwarding_enabled          = var.network_interfaces[nk].ip_forwarding_enabled
      dns_servers                    = var.network_interfaces[nk].dns_servers
      internal_dns_name_label        = var.network_interfaces[nk].internal_dns_name_label
      mac_address                    = try(nic.output.properties.macAddress, null)
      virtual_machine_id             = try(nic.output.properties.virtualMachine.id, null)
      applied_dns_servers            = try(nic.output.properties.dnsSettings.appliedDnsServers, [])
      internal_domain_name_suffix    = try(nic.output.properties.dnsSettings.internalDomainNameSuffix, null)
      private_ip_address = try([
        for config in nic.output.properties.ipConfigurations :
        config.properties.privateIPAddress if try(config.properties.primary, false)
      ][0], null)
      private_ip_addresses = try([
        for config in nic.output.properties.ipConfigurations :
        config.properties.privateIPAddress
      ], [])
      ip_configuration = try([
        for config in nic.output.properties.ipConfigurations : {
          name                          = config.name
          primary                       = try(config.properties.primary, null)
          private_ip_address            = try(config.properties.privateIPAddress, null)
          private_ip_address_allocation = try(config.properties.privateIPAllocationMethod, null)
          private_ip_address_version    = try(config.properties.privateIPAddressVersion, null)
          subnet_id                     = try(config.properties.subnet.id, null)
          public_ip_address_id          = try(config.properties.publicIPAddress.id, null)
          gateway_load_balancer_frontend_ip_configuration_id = try(
            config.properties.gatewayLoadBalancer.id, null
          )
        }
      ], [])
    }
  }
  public_ips_output = {
    for key, pip in azapi_resource.virtualmachine_public_ips : key => {
      id                      = pip.id
      name                    = pip.name
      location                = pip.location
      resource_group_name     = var.resource_group_name
      tags                    = pip.tags
      allocation_method       = var.public_ip_configuration_details.allocation_method
      ddos_protection_mode    = var.public_ip_configuration_details.ddos_protection_mode
      ddos_protection_plan_id = var.public_ip_configuration_details.ddos_protection_plan_id
      domain_name_label       = var.public_ip_configuration_details.domain_name_label
      idle_timeout_in_minutes = var.public_ip_configuration_details.idle_timeout_in_minutes
      ip_version              = var.public_ip_configuration_details.ip_version
      sku                     = var.public_ip_configuration_details.sku
      sku_tier                = var.public_ip_configuration_details.sku_tier
      zones                   = var.public_ip_configuration_details.zones
      ip_address              = try(pip.output.properties.ipAddress, null)
      fqdn                    = try(pip.output.properties.dnsSettings.fqdn, null)
    }
  }
}
