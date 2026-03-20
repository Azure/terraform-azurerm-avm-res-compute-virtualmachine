terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# tflint-ignore: terraform_module_provider_declaration, terraform_output_separate, terraform_variable_separate
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.5.0"

  availability_zones_filter = true
}

locals {
  deployment_region = "canadacentral" #temporarily pinning on single region
  tags = {
    scenario = "linux_os_managed_disk"
  }
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions_by_name) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.deployment_region].zones)
  min = 1
}

resource "azurerm_resource_group" "this_rg" {
  location = local.deployment_region
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}

module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = azurerm_resource_group.this_rg.location
  cache_results = true
  vm_filters = {
    min_vcpus                      = 2
    max_vcpus                      = 2
    encryption_at_host_supported   = true
    accelerated_networking_enabled = true
    premium_io_supported           = true
    location_zone                  = random_integer.zone_index.result
  }

  depends_on = [random_integer.zone_index]
}

module "natgateway" {
  source  = "Azure/avm-res-network-natgateway/azurerm"
  version = "0.2.1"

  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.nat_gateway.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  enable_telemetry    = true
  public_ips = {
    public_ip_1 = {
      name = "nat_gw_pip1"
    }
  }
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "=0.8.1"

  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  name                = module.naming.virtual_network.name_unique
  subnets = {
    vm_subnet_1 = {
      name             = "${module.naming.subnet.name_unique}-1"
      address_prefixes = ["10.0.1.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
  }
}

data "azurerm_client_config" "current" {}

# Look up the latest Ubuntu 20.04 Gen2 image version for creating a managed disk
data "azurerm_platform_image" "ubuntu" {
  location  = azurerm_resource_group.this_rg.location
  offer     = "0001-com-ubuntu-server-focal"
  publisher = "Canonical"
  sku       = "20_04-lts-gen2"
}

# Create a managed disk from a platform image to simulate a pre-existing OS disk
# In real-world scenarios, this disk would come from a backup restore, VHD import, or disk copy
resource "azurerm_managed_disk" "os_disk" {
  create_option        = "FromImage"
  location             = azurerm_resource_group.this_rg.location
  name                 = "${module.naming.managed_disk.name_unique}-os"
  resource_group_name  = azurerm_resource_group.this_rg.name
  storage_account_type = "Premium_LRS"
  hyper_v_generation   = "V2"
  image_reference_id   = "/Subscriptions/${data.azurerm_client_config.current.subscription_id}/Providers/Microsoft.Compute/Locations/${azurerm_resource_group.this_rg.location}/Publishers/${data.azurerm_platform_image.ubuntu.publisher}/ArtifactTypes/VMImage/Offers/${data.azurerm_platform_image.ubuntu.offer}/Skus/${data.azurerm_platform_image.ubuntu.sku}/Versions/${data.azurerm_platform_image.ubuntu.version}"
  os_type              = "Linux"
  tags                 = local.tags
  zone                 = random_integer.zone_index.result
}

# Create a Linux VM by attaching the pre-existing managed disk as the OS disk
module "testvm" {
  source = "../../"

  location = azurerm_resource_group.this_rg.location
  name     = module.naming.virtual_machine.name_unique
  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }
  resource_group_name = azurerm_resource_group.this_rg.name
  zone                = random_integer.zone_index.result
  enable_telemetry    = var.enable_telemetry
  os_disk_attach_mode = true
  os_managed_disk_id  = azurerm_managed_disk.os_disk.id
  os_type             = "Linux"
  sku_size            = module.vm_sku.sku
  tags                = local.tags
}
