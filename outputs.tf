




















output "testoutput" {
    value = length(split("/","Storage Blob Data Contributor"))
}

output "virtual_machine" {
 value = (lower(var.virtualmachine_os_type) == "windows") ? azurerm_windows_virtual_machine.this[0] : azurerm_linux_virtual_machine.this[0]
 description = "value"
 #sensitive = true
}

output "virtual_machine_outputs" {
    value = (lower(var.virtualmachine_os_type) == "windows") ? local.windows_virtual_machine_output_map : local.linux_virtual_machine_output_map
}

output "network_interfaces" {
    value = azurerm_network_interface.virtualmachine_network_interfaces
}

output "public_ips" {
    value = azurerm_public_ip.virtualmachine_public_ips
}

output "data_disks" {
    value = azurerm_managed_disk.this
}

output "system_managed_identity" {
    value = local.system_managed_identity_id
}

