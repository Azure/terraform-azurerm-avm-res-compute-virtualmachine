#get the resource group information 
data "azurerm_resource_group" "virtualmachine_deployment" {
  name = var.resource_group
}

#Get the Vnet's information
data "azapi_resource" "virtualmachine_virtual_network" {
  resource_id            = var.virtual_network_resource_id
  response_export_values = ["*"]
  type                   = "Microsoft.Network/virtualNetworks@2023-04-01"
}

#create the namestring
#create a random string for uniqueness during redeployments using the same values
resource "random_string" "namestring" {
  length  = 4
  special = false
  upper   = false
  lower   = true
}

#create the Nics
resource "azurerm_network_interface" "virtualmachine_network_interfaces" {
  for_each            = { for subnet in local.nic_subnets : subnet.name => subnet }
  name                = "${var.virtualmachine_name}-${each.value.name}-nic-${random_string.namestring.result}"
  location            = data.azurerm_resource_group.virtualmachine_deployment.location
  resource_group_name = data.azurerm_resource_group.virtualmachine_deployment.name


  ip_configuration {
    name                          = "${var.virtualmachine_name}-${each.value.name}-ipconfig-${random_string.namestring.result}"
    subnet_id                     = each.value.id
    private_ip_address_allocation = "Dynamic"
  }
}