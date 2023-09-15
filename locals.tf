locals {
  #nic_subnets = [for subnet in jsondecode(data.azapi_resource.virtualmachine_virtual_network.output).properties.subnets : subnet if contains(var.subnet_names, subnet.name)]
  flattened_nics = flatten([for nic_key, nic in var.virtualmachine_network_interfaces : [
        for ip_config_key, ip_config in nic.ip_configurations : {
            nic_key = nic_key
            ip_config_key = ip_config_key
            nic_name = nic.name
            ip_config_name = ip_config.name
            create_public_ip_address = ip_config.create_public_ip_address
            }
        ]
    ])
}
