# Supporting resources for the upgrade test. They live in their own test state, so the state of
# the machines under test holds only what the module manages.
data "azapi_client_config" "this" {}

locals {
  ubuntu_image_sku_id = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Compute/locations/${var.location}/publishers/Canonical/artifacttypes/vmimage/offers/0001-com-ubuntu-server-jammy/skus/22_04-lts-gen2"
  zone                = "1"
}

resource "random_string" "suffix" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  location  = var.location
  name      = "rg-vm-osdisk-upgrade-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.this.subscription_id}"
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
}

resource "azapi_resource" "virtual_network" {
  location  = var.location
  name      = "vnet-vm-osdisk-upgrade"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
      subnets = [
        {
          name = "vm"
          properties = {
            addressPrefix = "10.0.1.0/24"
          }
        }
      ]
    }
  }
}

# A disk attached with os_managed_disk_id has to hold an operating system, so it is created from
# the newest Ubuntu image, the way a restored or imported disk would arrive.
data "azapi_resource_action" "ubuntu_image_versions" {
  type        = "Microsoft.Compute/locations/publishers/artifacttypes/offers/skus@2024-07-01"
  resource_id = local.ubuntu_image_sku_id
  action      = "versions"
  method      = "GET"
  query_parameters = {
    "$orderby" = ["name desc"]
    "$top"     = ["1"]
  }
  response_export_values = ["*"]
}

resource "azapi_resource" "attached_os_disk" {
  location  = var.location
  name      = "disk-attached-os"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Compute/disks@2024-03-02"
  body = {
    properties = {
      creationData = {
        createOption = "FromImage"
        imageReference = {
          id = data.azapi_resource_action.ubuntu_image_versions.output[0].id
        }
      }
      hyperVGeneration = "V2"
      osType           = "Linux"
    }
    sku = {
      name = "Premium_LRS"
    }
    zones = [local.zone]
  }
}
