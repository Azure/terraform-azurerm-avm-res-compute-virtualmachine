#output "network_data" {
#  value = jsondecode(data.azapi_resource.virtualmachine_virtual_network.output).properties.subnets[*].name
#}

#output "ids" {
#  value = [for subnet in jsondecode(data.azapi_resource.virtualmachine_virtual_network.output).properties.subnets : subnet if contains(var.subnet_names, subnet.name)]
#}

output "testoutput" {
    value = local.system_managed_identity_id
}

output "virtual_machine" {
 value = azurerm_linux_virtual_machine.this
 description = "value"
}