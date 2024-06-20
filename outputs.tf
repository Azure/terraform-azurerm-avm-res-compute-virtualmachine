output "admin_password" {
  description = "Returns the admin password if installation is configured to use the password.  Otherwise returns null"
  sensitive   = true
  value       = (lower(var.os_type) == "windows") ? local.admin_password_windows : local.admin_password_linux
}

output "admin_ssh_keys" {
  description = "Returns a list containing all of the provided or generated ssh keys. This is a single key if the generation option is selected and no additional keys are provided."
  sensitive   = true
  value       = local.admin_ssh_keys
}

output "admin_username" {
  description = "The admin username used when creating this virtual machine."
  value       = var.admin_username
}

output "data_disks" {
  description = "The full ARM object map associated with any deployed data disk(s). Exporting this in the event that a disk property not exposed as part of the azurerm vm export is required."
  value       = azurerm_managed_disk.this
}

output "name" {
  description = "The name used for the virtual machines name."
  value       = var.name
}

output "network_interfaces" {
  description = "The full ARM object map associated with the deployed network interface(s). Exporting this in the event that a nic property not exposed as part of the azurerm vm export is required."
  value       = azurerm_network_interface.virtualmachine_network_interfaces
}

output "public_ips" {
  description = "The full ARM object map associated with any deployed public ip(s). Exporting this in the event that a public ip property not exposed as part of the azurerm vm export is required."
  value       = azurerm_public_ip.virtualmachine_public_ips
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
