output "admin_generated_ssh_private_key" {
  description = "Returns the private key for the generated ssh key. This is only available if the generation option is selected and no additional keys are provided."
  sensitive   = true
  value       = local.admin_ssh_key_secret_value
}

output "admin_password" {
  description = "Returns the admin password if installation is configured to use the password.  Otherwise returns null"
  sensitive   = true
  value       = (lower(var.os_type) == "windows") ? local.admin_password_windows : local.admin_password_linux
}

output "admin_ssh_keys" {
  description = "Returns a list containing all of the provided or generated public ssh keys. This is a single key if the generation option is selected and no additional keys are provided."
  sensitive   = true
  value       = local.admin_ssh_keys
}

output "admin_username" {
  description = "The admin username used when creating this virtual machine."
  value       = local.admin_username
}

output "data_disks" {
  description = "The map of deployed data disk(s), keyed as supplied to `data_disk_managed_disks`. The attribute names are preserved from the `azurerm` provider so existing expressions keep working after the AzAPI migration. Server-populated values such as `disk_size_bytes` and `unique_id` are only available after apply. For the unshaped ARM representation use `data_disks_azapi`."
  value       = local.data_disks_output
}

output "data_disks_azapi" {
  description = "The full AzAPI object map for any deployed data disk(s). Attribute names follow the ARM schema. Use this when a property is required that `data_disks` does not expose."
  value       = azapi_resource.this_data_disk
}

output "name" {
  description = "The name used for the virtual machines name."
  value       = var.name
}

output "network_interfaces" {
  description = "The map of deployed network interface(s), keyed as supplied to `network_interfaces`. The attribute names are preserved from the `azurerm` provider so existing expressions keep working after the AzAPI migration. Server-populated values such as `mac_address` and `private_ip_address` are only available after apply. For the unshaped ARM representation use `network_interfaces_azapi`."
  value       = local.network_interfaces_output
}

output "network_interfaces_azapi" {
  description = "The full AzAPI object map for the deployed network interface(s). Attribute names follow the ARM schema, and the interface associations appear as properties of the interface body. Use this when a property is required that `network_interfaces` does not expose."
  value       = azapi_resource.virtualmachine_network_interfaces
}

output "public_ips" {
  description = "The map of deployed public ip(s), keyed by `<network interface key>-<ip configuration key>`. The attribute names are preserved from the `azurerm` provider so existing expressions keep working after the AzAPI migration. Server-populated values such as `ip_address` and `fqdn` are only available after apply. For the unshaped ARM representation use `public_ips_azapi`."
  value       = local.public_ips_output
}

output "public_ips_azapi" {
  description = "The full AzAPI object map for any deployed public ip(s). Attribute names follow the ARM schema. Use this when a property is required that `public_ips` does not expose."
  value       = azapi_resource.virtualmachine_public_ips
}

output "resource" {
  description = "The full object for the deployed virtual machine.  This is marked sensitive as it contains specific sensitive values"
  sensitive   = true
  value       = (lower(var.os_type) == "windows") ? azurerm_windows_virtual_machine.this[0] : azurerm_linux_virtual_machine.this[0]
}

output "resource_id" {
  description = "The Azure resource id for the deployed virtual machine"
  value       = (lower(var.os_type) == "windows") ? azurerm_windows_virtual_machine.this[0].id : azurerm_linux_virtual_machine.this[0].id
}

output "system_assigned_mi_principal_id" {
  description = "The principal id of the system managed identity assigned to the virtual machine"
  value       = var.managed_identities.system_assigned == true ? ((lower(var.os_type) == "windows") ? azurerm_windows_virtual_machine.this[0].identity[0].principal_id : azurerm_linux_virtual_machine.this[0].identity[0].principal_id) : ""
}

output "virtual_machine" {
  description = "The full object for the deployed virtual machine.  This is marked sensitive as it contains specific sensitive values. This output has been duplicated to the resource output to comply with the spec and may be deprecated in the future."
  sensitive   = true
  value       = (lower(var.os_type) == "windows") ? azurerm_windows_virtual_machine.this[0] : azurerm_linux_virtual_machine.this[0]
}

output "virtual_machine_azurerm" {
  description = <<VIRTUAL_MACHINE_AZURERM
    The default attributes exported by the azurerm provider.  These are defined as a map containing the following attributes
    id                   = The Azure resource ID of the deployed virtual machine
    identity             = { #An identity map with the following attributes
        principal_id     = The Principal ID associated with the virtual machine's system assigned managed identity
        tenant_id        = The Tenant ID associated with the virtual machine's system assigned managed identity
    }
    private_ip_address   = The primary private IP address of the deployed virtual machine
    private_ip_addresses = A list of Private IP Addresses assigned to this Virtual Machine.
    public_ip_address    = The Primary Public IP Address assigned to this Virtual Machine.
    public_ip_addresses  = A list of the Public IP Addresses assigned to this Virtual Machine.
    virtual_machine_id   = A 128-bit identifier which uniquely identifies this Virtual Machine.
    VIRTUAL_MACHINE_AZURERM
  value       = (lower(var.os_type) == "windows") ? local.windows_virtual_machine_output_map : local.linux_virtual_machine_output_map
}
