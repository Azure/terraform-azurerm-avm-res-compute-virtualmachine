terraform {
  required_version = "~> 1.6"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.13"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

### this segment of code gets valid vm skus for deployment in the current subscription
data "azurerm_subscription" "current" {
}

#get the full sku list (azapi doesn't currently have a good way to filter the api call)
data "azapi_resource_list" "example" {
  type                   = "Microsoft.Compute/skus?$filter=location%20eq%20%27${var.deployment_region}%27@2021-07-01"
  parent_id              = data.azurerm_subscription.current.id
  response_export_values = ["*"]
}

locals {
  #filter the location output for the current region, virtual machine resources, and filter out entries that don't include the capabilities list
  location_valid_vms = [
    for location in data.azapi_resource_list.example.output.value : location
    if length(location.restrictions) < 1 &&       #there are no restrictions on deploying the sku (i.e. allowed for deployment)
    location.resourceType == "virtualMachines" && #and the sku is a virtual machine
    !strcontains(location.name, "C") &&           #no confidential vm skus
    !strcontains(location.name, "B") &&           #no B skus
    length(try(location.capabilities, [])) > 1    #avoid skus where the capabilities list isn't defined
  ]

  #filter the region virtual machines by desired capabilities (v1/v2 support, 2 cpu, and encryption at host)
  deploy_skus = [
    for sku in local.location_valid_vms : sku
    if length([
      for capability in sku.capabilities : capability
      if(capability.name == "HyperVGenerations" && capability.value == "V1,V2") ||
      (capability.name == "vCPUs" && capability.value == "2") ||
      (capability.name == "EncryptionAtHostSupported" && capability.value == "True") ||
      (capability.name == "CpuArchitectureType" && capability.value == "x64")
    ]) == 4
  ]
}

resource "random_integer" "deploy_sku" {
  min = 0
  max = length(local.deploy_skus) - 1
}