locals {
  admin_password_linux = (lower(var.os_type) == "linux") ? (
    var.disable_password_authentication == false ? (                                                         #if os is linux and password authentication is enabled
      var.generate_admin_password_or_ssh_key ? random_password.admin_password[0].result : var.admin_password #use generated password, password variable
    ) : null
  ) : null
  #set the admin password to either a generated value or the entered value
  admin_password_windows = (lower(var.os_type) == "windows") ? (
    var.generate_admin_password_or_ssh_key ? random_password.admin_password[0].result : var.admin_password #use generated password, password variable
  ) : null
  #format the admin ssh key so it can be concat'ed to the other keys.
  admin_ssh_key = (((var.generate_admin_password_or_ssh_key == true) && (lower(var.os_type) == "linux")) ?
    [{
      public_key = tls_private_key.this[0].public_key_openssh
      username   = var.admin_username
    }] :
  [])
  #concat the ssh key values list 
  admin_ssh_keys = concat(var.admin_ssh_keys, local.admin_ssh_key)
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
  generated_secret_expiration_date_utc = var.generated_secrets_key_vault_secret_config != null ? formatdate("YYYY-MM-DD'T'hh:mm:ssZ", (timeadd(timestamp(), "${var.generated_secrets_key_vault_secret_config.expiration_date_length_in_days * 24}h"))) : null
  linux_virtual_machine_output_map = (lower(var.os_type) == "linux") ? {
    id                   = azurerm_linux_virtual_machine.this[0].id
    identity             = azurerm_linux_virtual_machine.this[0].identity
    private_ip_address   = azurerm_linux_virtual_machine.this[0].private_ip_address
    private_ip_addresses = azurerm_linux_virtual_machine.this[0].private_ip_addresses
    public_ip_address    = azurerm_linux_virtual_machine.this[0].public_ip_address
    public_ip_addresses  = azurerm_linux_virtual_machine.this[0].public_ip_addresses
    virtual_machine_id   = azurerm_linux_virtual_machine.this[0].virtual_machine_id
  } : null
  #set the type value for the managed identity that is used by azurerm
  managed_identity_type = var.managed_identities.system_assigned ? ((length(var.managed_identities.user_assigned_resource_ids) > 0) ? "SystemAssigned, UserAssigned" : "SystemAssigned") : ((length(var.managed_identities.user_assigned_resource_ids) > 0) ? "UserAssigned" : null)
  #flatten the ASG's for the nics
  nics_asgs = { for asg in flatten([
    for nk, nv in var.network_interfaces : [
      for ask, asv in nv.application_security_groups : {
        nic_key                     = nk
        asg_key                     = ask
        application_security_groups = asv
      }
    ]
  ]) : "${asg.nic_key}-${asg.asg_key}" => asg }
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
  #flatten the ip_configs for the nics and app gateway pools
  nics_ip_configs_app_gw_pools = { for ag_pool in flatten([
    for nk, nv in var.network_interfaces : [
      for ipck, ipcv in nv.ip_configurations : [
        for agk, agv in ipcv.app_gateway_backend_pools : {
          nic_key       = nk
          ipconfig_key  = ipck
          ipconfig_name = ipcv.name
          ag_key        = agk
          ag_pools      = agv
        }
      ]
    ]
  ]) : "${ag_pool.nic_key}-${ag_pool.ipconfig_key}-${ag_pool.ag_key}" => ag_pool }
  #flatten the ip_configs for the nics and load-balancer nat rules
  nics_ip_configs_lb_nat_rules = { for lb_nat_rule in flatten([
    for nk, nv in var.network_interfaces : [
      for ipck, ipcv in nv.ip_configurations : [
        for lbk, lbv in ipcv.load_balancer_nat_rules : {
          nic_key       = nk
          ipconfig_key  = ipck
          ipconfig_name = ipcv.name
          lb_key        = lbk
          lb_nat_rules  = lbv
        }
      ]
    ]
  ]) : "${lb_nat_rule.nic_key}-${lb_nat_rule.ipconfig_key}-${lb_nat_rule.lb_key}" => lb_nat_rule }
  #flatten the ip_configs for the nics and load-balancer pools
  nics_ip_configs_lb_pools = { for lb_pool in flatten([
    for nk, nv in var.network_interfaces : [
      for ipck, ipcv in nv.ip_configurations : [
        for lbk, lbv in ipcv.load_balancer_backend_pools : {
          nic_key       = nk
          ipconfig_key  = ipck
          ipconfig_name = ipcv.name
          lb_key        = lbk
          lb_pools      = lbv
        }
      ]
    ]
  ]) : "${lb_pool.nic_key}-${lb_pool.ipconfig_key}-${lb_pool.lb_key}" => lb_pool }
  #flatten the NSG's for the nics
  nics_nsgs = { for nsg in flatten([
    for nk, nv in var.network_interfaces : [
      for nsk, nsv in nv.network_security_groups : {
        nic_key                 = nk
        nsg_key                 = nsk
        network_security_groups = nsv
      }
    ]
  ]) : "${nsg.nic_key}-${nsg.nsg_key}" => nsg }
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
  #concat the input variable with the simple list going forward - this is a placeholder so that we can continue to reference the local source image reference value when it includes the simpleOS option.
  source_image_reference = var.source_image_reference
  #get the first system managed identity id if it is provisioned and depending on whether the vm type is linux or windows
  system_managed_identity_id = var.managed_identities.system_assigned ? ((lower(var.os_type) == "windows") ? azurerm_windows_virtual_machine.this[0].identity[0].principal_id : azurerm_linux_virtual_machine.this[0].identity[0].principal_id) : null
  #merge the resource group tags if tag inheritance is on.  Add this back in if agreed, passing through the resource tags for now.
  #tags = var.inherit_tags ? merge(data.azurerm_resource_group.virtualmachine_deployment.tags, var.tags) : var.tags
  tags = var.tags
  #get the vm id value depending on whether the vm is linux or windows
  virtualmachine_resource_id = (lower(var.os_type) == "windows") ? azurerm_windows_virtual_machine.this[0].id : azurerm_linux_virtual_machine.this[0].id
  windows_virtual_machine_output_map = (lower(var.os_type) == "windows") ? {
    id                   = azurerm_windows_virtual_machine.this[0].id
    identity             = azurerm_windows_virtual_machine.this[0].identity
    private_ip_address   = azurerm_windows_virtual_machine.this[0].private_ip_address
    private_ip_addresses = azurerm_windows_virtual_machine.this[0].private_ip_addresses
    public_ip_address    = azurerm_windows_virtual_machine.this[0].public_ip_address
    public_ip_addresses  = azurerm_windows_virtual_machine.this[0].public_ip_addresses
    virtual_machine_id   = azurerm_windows_virtual_machine.this[0].virtual_machine_id
  } : null
}
