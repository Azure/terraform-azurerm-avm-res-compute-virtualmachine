locals {
  #if automatic updates are set in multiple places, prefer the var.automatic_updates_enabled value.
  #both inputs default to null/true respectively, so an unset configuration resolves to `true`.
  #after deprecation, set automatic_updates_enabled to var.automatic_updates_enabled
  automatic_updates_enabled = var.automatic_updates_enabled != null ? var.automatic_updates_enabled : var.enable_automatic_updates
  #flatten the role assignments for the disks
  disks_role_assignments = { for ra in flatten([
    for dk, dv in var.data_disk_managed_disks : [
      for rk, rv in dv.role_assignments : {
        disk_key        = dk
        ra_key          = rk
        role_assignment = rv
      }
    ]
  ]) : "${ra.disk_key}-${ra.ra_key}" => ra }
  linux_virtual_machine_output_map = (lower(var.os_type) == "linux") ? {
    id = azapi_resource.this_linux_virtual_machine[0].id
    # ARM returns the identity block directly. The azurerm provider exposed it as a single-element
    # list, so the shape is preserved here.
    identity             = local.linux_vm_identity_output
    private_ip_address   = local.virtual_machine_private_ip_address
    private_ip_addresses = local.virtual_machine_private_ip_addresses
    public_ip_address    = local.virtual_machine_public_ip_address
    public_ip_addresses  = local.virtual_machine_public_ip_addresses
    virtual_machine_id   = try(azapi_resource.this_linux_virtual_machine[0].output.properties.vmId, null)
  } : null
  #set the type value for the managed identity that is used by azurerm
  managed_identity_type = var.managed_identities.system_assigned ? ((length(var.managed_identities.user_assigned_resource_ids) > 0) ? "SystemAssigned, UserAssigned" : "SystemAssigned") : ((length(var.managed_identities.user_assigned_resource_ids) > 0) ? "UserAssigned" : null)
  #flatten the diag settings for the nics
  nics_diag_settings = { for ds in flatten([
    for nk, nv in var.network_interfaces : [
      for dk, dv in nv.diagnostic_settings : {
        nic_key            = nk
        ds_key             = dk
        diagnostic_setting = dv
      }
    ]
  ]) : "${ds.nic_key}-${ds.ds_key}" => ds }
  #flatten the ip_configs for the nics
  nics_ip_configs = { for ip_config in flatten([
    for nk, nv in var.network_interfaces : [
      for ipck, ipcv in nv.ip_configurations : {
        nic_key      = nk
        ipconfig_key = ipck
        ipconfig     = ipcv
      }
    ]
  ]) : "${ip_config.nic_key}-${ip_config.ipconfig_key}" => ip_config }
  #flatten the role assignments for the nics
  nics_role_assignments = { for ra in flatten([
    for nk, nv in var.network_interfaces : [
      for rk, rv in nv.role_assignments : {
        nic_key         = nk
        ra_key          = rk
        role_assignment = rv
      }
    ]
  ]) : "${ra.nic_key}-${ra.ra_key}" => ra }
  #azurerm vm resources implement network interfaces based on the order of input. Ordering the inputs so that the nic tagged as primary will be implemented first.
  ordered_network_interface_keys = concat(
    [for nic, value in var.network_interfaces : nic if value.is_primary],
    [for nic, value in var.network_interfaces : nic if !value.is_primary]
  )
  # Whether the OS disk is being imported from an existing managed disk (Attach mode)
  # Uses var.os_disk_attach_mode (known at plan time) rather than var.os_managed_disk_id != null
  # because os_managed_disk_id is typically a computed resource attribute (unknown at plan time),
  # which would make count expressions that depend on this local undeterminable during planning.
  os_disk_is_imported = var.os_disk_attach_mode
  #the OS disk is an inline block on the vm resource rather than a separate managed disk, so its resource id is read
  #back off the created virtual machine.
  os_disk_resource_id = (lower(var.os_type) == "windows") ? try(azapi_resource.this_windows_virtual_machine[0].output.properties.storageProfile.osDisk.managedDisk.id, null) : try(azapi_resource.this_linux_virtual_machine[0].output.properties.storageProfile.osDisk.managedDisk.id, null)
  #concat the input variable with the simple list going forward - this is a placeholder so that we can continue to reference the local source image reference value when it includes the simpleOS option.
  source_image_reference = var.source_image_reference
  #get the first system managed identity id if it is provisioned and depending on whether the vm type is linux or windows
  system_managed_identity_id = var.managed_identities.system_assigned ? ((lower(var.os_type) == "windows") ? try(azapi_resource.this_windows_virtual_machine[0].output.identity.principalId, null) : try(azapi_resource.this_linux_virtual_machine[0].output.identity.principalId, null)) : null
  #merge the resource group tags if tag inheritance is on.  Add this back in if agreed, passing through the resource tags for now.
  #tags = var.inherit_tags ? merge(data.azurerm_resource_group.virtualmachine_deployment.tags, var.tags) : var.tags
  tags = var.tags
  #get the vm id value depending on whether the vm is linux or windows
  virtualmachine_resource_id = (lower(var.os_type) == "windows") ? azapi_resource.this_windows_virtual_machine[0].id : azapi_resource.this_linux_virtual_machine[0].id
  windows_virtual_machine_output_map = (lower(var.os_type) == "windows") ? {
    id = azapi_resource.this_windows_virtual_machine[0].id
    # ARM returns the identity block directly. The azurerm provider exposed it as a single-element
    # list, so the shape is preserved here.
    identity             = local.windows_vm_identity_output
    private_ip_address   = local.virtual_machine_private_ip_address
    private_ip_addresses = local.virtual_machine_private_ip_addresses
    public_ip_address    = local.virtual_machine_public_ip_address
    public_ip_addresses  = local.virtual_machine_public_ip_addresses
    virtual_machine_id   = try(azapi_resource.this_windows_virtual_machine[0].output.properties.vmId, null)
  } : null
}
