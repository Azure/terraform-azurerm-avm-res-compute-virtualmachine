locals {
  #get the vm id value depending on whether the vm is linux or windows
  virtualmachine_resource_id = (lower(var.virtualmachine_os_type) == "windows") ? azurerm_windows_virtual_machine.this[0].id : azurerm_linux_virtual_machine.this[0].id

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

  #concat the input variable with the simple list going forward
  source_image_reference = var.source_image_reference

  #create a string to help with naming uniqueness when resource names are re-used
  name_string = var.append_name_string_suffix ? "-${substr(sha256(var.virtualmachine_name), 0, var.name_string_suffix_length)}" : ""

  #create an object that can be converted to JSON for the AMA agent's identity setting
  azure_monitor_agent_authentication_user_assigned_identity_settings = {
    authentication = {
      managedIdentity = {
        identifier-name  = "mi_res_id"
        identifier-value = var.azure_monitor_agent_extension_settings.user_assigned_managed_identity_resource_id
      }
    }
  }

  #create an object that can be converted to JSON for the domain join extension
  domain_join_extension_settings = var.domain_join_the_windows_vm ? {
    Name    = var.domain_join_extension_values.domain_name
    OUpath  = var.domain_join_extension_values.domain_join_ou_path_for_vm
    User    = "${var.domain_join_extension_values.domain_join_user_name}\\${var.domain_join_extension_values.domain_name}"
    Restart = var.domain_join_extension_values.domain_join_restart
    Options = var.domain_join_extension_values.domain_join_options
  } : null

  domain_join_extension_protected_settings = var.domain_join_the_windows_vm ? {
    Password = local.domain_join_user_password
  } : null

  #set the admin password to either a generated value or the entered value
  admin_password = var.generate_admin_password_or_ssh_key ? random_password.admin_password.result : coalesce(var.admin_password, (data.azurerm_key_vault_secret.admin_password[0].value))

  #set the domain join user password to either the manually entered value or the value from a vault
  domain_join_user_password = var.domain_join_the_windows_vm ? coalesce(var.domain_join_extension_values.domain_join_user_password, data.azurerm_key_vault_secret.domain_join_user_password[0].value) : null

  #set the resource deployment location. Default to the resource group location
  location = coalesce(var.location, data.azurerm_resource_group.virtualmachine_deployment.location)

  #merge the resource group tags if tag inheritance is on
  tags = var.inherit_tags ? merge(data.azurerm_resource_group.virtualmachine_deployment.tags, var.tags) : var.tags

}
