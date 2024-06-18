### this segment of code gets valid vm skus for deployment in the current subscription
data "azurerm_subscription" "current" {}

#get the full sku list (azapi doesn't currently have a good way to filter the api call)
data "azapi_resource_list" "example" {
  parent_id              = data.azurerm_subscription.current.id
  type                   = "Microsoft.Compute/skus?$filter=location%20eq%20%27${var.deployment_region}%27@2021-07-01"
  response_export_values = ["*"]
}

locals {
  #filter the region virtual machines by desired capabilities (v1/v2 support, 2 cpu, and encryption at host)
  deploy_skus = [
    for sku in local.location_valid_vms : sku
    if length([
      for capability in sku.capabilities : capability
      if(capability.name == "HyperVGenerations" && capability.value == "V1,V2") ||
      (capability.name == "vCPUs" && capability.value == "2") ||
      (capability.name == "EncryptionAtHostSupported" && capability.value == "True") ||
      (capability.name == "CpuArchitectureType" && capability.value == "x64") ||
      (capability.name == "PremiumIO" && capability.value == "True")
    ]) == 5
  ]
  #filter the location output for the current region, virtual machine resources, and filter out entries that don't include the capabilities list
  location_valid_vms = [
    for location in jsondecode(data.azapi_resource_list.example.output).value : location
    if length(location.restrictions) < 1 &&       #there are no restrictions on deploying the sku (i.e. allowed for deployment)
    location.resourceType == "virtualMachines" && #and the sku is a virtual machine
    !strcontains(location.name, "C") &&           #no confidential vm skus
    !strcontains(location.name, "B") &&           #no B skus
    length(try(location.capabilities, [])) > 1    #avoid skus where the capabilities list isn't defined
  ]
}

resource "random_integer" "deploy_sku" {
  max = length(local.deploy_skus) - 1
  min = 0
}