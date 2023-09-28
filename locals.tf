locals {
  #set the resource deployment location. Default to the resource group location
  location = coalesce(var.location, data.azurerm_resource_group.virtualmachine_deployment.location)

  #merge the resource group tags if tag inheritance is on
  tags = var.inherit_tags ? merge(data.azurerm_resource_group.virtualmachine_deployment.tags, var.tags) : var.tags

  #create a string to help with naming uniqueness when resource names are re-used
  name_string = var.append_name_string_suffix ? "-${substr(sha256(var.name), 0, var.name_string_suffix_length)}" : ""
  
  #get the vm id value depending on whether the vm is linux or windows
  virtualmachine_resource_id = (lower(var.virtualmachine_os_type) == "windows") ? azurerm_windows_virtual_machine.this[0].id : azurerm_linux_virtual_machine.this[0].id

  #concat the input variable with the simple list going forward - this is a placeholder so that we can continue to reference the local source image reference value when it includes the simpleOS option.
  source_image_reference = var.source_image_reference

  #get the first system managed identity id if it is provisioned and depending on whether the vm type is linux or windows
  system_managed_identity_id = var.managed_identities.system_assigned ? ((lower(var.virtualmachine_os_type) == "windows") ? azurerm_windows_virtual_machine.this[0].identity[0].principal_id : azurerm_linux_virtual_machine.this[0].identity[0].principal_id) : null

  #set the type value for the managed identity that is used by azurerm
  managed_identity_type = var.managed_identities.system_assigned ? ((length(var.managed_identities.user_assigned_resource_ids) > 0) ? "SystemAssigned, UserAssigned" : "SystemAssigned") : ((length(var.managed_identities.user_assigned_resource_ids) > 0) ? "UserAssigned" : null)

  #flatten the network interface vars to properly create public ips that can be referenced in the ipconfig
  flattened_nics = flatten([for nic_key, nic in var.network_interfaces : [
    for ip_config_key, ip_config in nic.ip_configurations : {
      nic_key                  = nic_key
      ip_config_key            = ip_config_key
      nic_name                 = nic.name
      ip_config_name           = ip_config.name
      create_public_ip_address = ip_config.create_public_ip_address
    }
    ]
  ])

  #format the admin ssh key so it can be concat'ed to the other keys.
  admin_ssh_key = (((var.generate_admin_password_or_ssh_key == true) && (lower(var.virtualmachine_os_type) == "linux")) ?
    [{
      public_key = tls_private_key.this[0].public_key_openssh
      username   = var.admin_username
    }] :
  [])

  #concat the ssh key values list 
  admin_ssh_keys = concat(var.admin_ssh_keys, local.admin_ssh_key)

  #set the admin password to either a generated value or the entered value
  admin_password = var.generate_admin_password_or_ssh_key ? random_password.admin_password.result : coalesce(var.admin_password, (data.azurerm_key_vault_secret.admin_password[0].value))


  linux_virtual_machine_output_map = (lower(var.virtualmachine_os_type) == "linux") ? {
    id                   = azurerm_linux_virtual_machine.this[0].id
    identity             = azurerm_linux_virtual_machine.this[0].identity
    private_ip_address   = azurerm_linux_virtual_machine.this[0].private_ip_address
    private_ip_addresses = azurerm_linux_virtual_machine.this[0].private_ip_addresses
    public_ip_address    = azurerm_linux_virtual_machine.this[0].public_ip_address
    public_ip_addresses  = azurerm_linux_virtual_machine.this[0].public_ip_addresses
    virtual_machine_id   = azurerm_linux_virtual_machine.this[0].virtual_machine_id
  } : null

  windows_virtual_machine_output_map = (lower(var.virtualmachine_os_type) == "windows") ? {
    id                   = azurerm_windows_virtual_machine.this[0].id
    identity             = azurerm_windows_virtual_machine.this[0].identity
    private_ip_address   = azurerm_windows_virtual_machine.this[0].private_ip_address
    private_ip_addresses = azurerm_windows_virtual_machine.this[0].private_ip_addresses
    public_ip_address    = azurerm_windows_virtual_machine.this[0].public_ip_address
    public_ip_addresses  = azurerm_windows_virtual_machine.this[0].public_ip_addresses
    virtual_machine_id   = azurerm_windows_virtual_machine.this[0].virtual_machine_id
  } : null

}
