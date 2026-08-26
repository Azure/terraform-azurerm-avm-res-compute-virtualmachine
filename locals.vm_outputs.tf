locals {
  # The azurerm virtual machine resource exposed private_ip_address, private_ip_addresses,
  # public_ip_address and public_ip_addresses as computed attributes. ARM does not return any of
  # them on the virtual machine; the azurerm provider derived them by reading the attached network
  # interfaces. These locals reproduce that derivation from the interface resources so the
  # virtual_machine_azurerm output keeps working after the migration.
  #
  # The interface order matters: azurerm reported the primary interface's primary IP configuration
  # as the singular address, so ordered_network_interface_keys drives the ordering here too.
  virtual_machine_ip_configurations = flatten([
    for key in local.ordered_network_interface_keys : [
      for config in try(azapi_resource.virtualmachine_network_interfaces[key].output.properties.ipConfigurations, []) : {
        nic_key            = key
        primary            = try(config.properties.primary, false)
        private_ip_address = try(config.properties.privateIPAddress, null)
        public_ip_id       = try(config.properties.publicIPAddress.id, null)
      }
    ]
  ])

  virtual_machine_private_ip_addresses = [
    for config in local.virtual_machine_ip_configurations :
    config.private_ip_address if config.private_ip_address != null
  ]
  virtual_machine_private_ip_address = try(local.virtual_machine_private_ip_addresses[0], null)

  # A public IP's address is only known once the public IP resource itself is read back, so the
  # addresses are taken from the public IP resources rather than the interface body.
  virtual_machine_public_ip_addresses = [
    for key, pip in azapi_resource.virtualmachine_public_ips :
    pip.output.properties.ipAddress if try(pip.output.properties.ipAddress, null) != null
  ]
  virtual_machine_public_ip_address = try(local.virtual_machine_public_ip_addresses[0], null)

  # azurerm modelled identity as a single-element list of objects. ARM returns one object, so it is
  # wrapped to preserve the shape consumers already index into.
  linux_vm_identity_output = local.managed_identity_type == null ? [] : [
    {
      type         = local.managed_identity_type
      principal_id = try(azapi_resource.this_linux_virtual_machine[0].output.identity.principalId, null)
      tenant_id    = try(azapi_resource.this_linux_virtual_machine[0].output.identity.tenantId, null)
      identity_ids = var.managed_identities.user_assigned_resource_ids
    }
  ]
  windows_vm_identity_output = local.managed_identity_type == null ? [] : [
    {
      type         = local.managed_identity_type
      principal_id = try(azapi_resource.this_windows_virtual_machine[0].output.identity.principalId, null)
      tenant_id    = try(azapi_resource.this_windows_virtual_machine[0].output.identity.tenantId, null)
      identity_ids = var.managed_identities.user_assigned_resource_ids
    }
  ]
}
