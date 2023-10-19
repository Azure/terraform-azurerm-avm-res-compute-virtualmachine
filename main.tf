#get the resource group information 
data "azurerm_resource_group" "virtualmachine_deployment" {
  name = var.resource_group
}
