output "virtual_machine" {
  value       = (lower(var.virtualmachine_os_type) == "windows") ? azurerm_windows_virtual_machine.this[0] : azurerm_linux_virtual_machine.this[0]
  description = "The full object for the deployed virtual machine.  This is marked sensitive as it contains specific sensitive values"
  sensitive   = true
}

output "virtual_machine_azurerm" {
  value       = (lower(var.virtualmachine_os_type) == "windows") ? local.windows_virtual_machine_output_map : local.linux_virtual_machine_output_map
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
}

output "network_interfaces" {
  value       = azurerm_network_interface.virtualmachine_network_interfaces
  description = "The full ARM object map associated with the deployed network interface(s). Exporting this in the event that a nic property not exposed as part of the azurerm vm export is required."
}

output "public_ips" {
  value       = azurerm_public_ip.virtualmachine_public_ips
  description = "The full ARM object map associated with any deployed public ip(s). Exporting this in the event that a public ip property not exposed as part of the azurerm vm export is required."
}

output "data_disks" {
  value       = azurerm_managed_disk.this
  description = "The full ARM object map associated with any deployed data disk(s). Exporting this in the event that a disk property not exposed as part of the azurerm vm export is required."
}

output "testoutput" {
  value = length(split("/", "Storage Blob Data Contributor"))
}
