# We pick a random region from this list.
locals {
  azure_regions = [
    "westeurope",
    "northeurope",
    "eastus",
    "eastus2",
    "westus",
    "westus2",
    "westus3",
    "southcentralus",
    "northcentralus",
    "centralus",
    "eastasia",
    "southeastasia",
  ]
}