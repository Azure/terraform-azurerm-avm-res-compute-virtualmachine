terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.42, < 5.0"
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
    key_vault {
      purge_soft_delete_on_destroy = true
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
  #deployment_region = module.regions.regions[random_integer.region_index.result].name
  deployment_region = "canadacentral" #temporarily pinning on single region
  tags = {
    scenario = "extension_protected_settings"
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

data "azapi_client_config" "current" {}

resource "azapi_resource" "this_rg" {
  location  = local.deployment_region
  name      = module.naming.resource_group.name_unique
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  tags      = local.tags
}

module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = azapi_resource.this_rg.location
  cache_results = true
  vm_filters = {
    min_vcpus     = 2
    max_vcpus     = 2
    location_zone = random_integer.zone_index.result
  }

  depends_on = [random_integer.zone_index]
}

module "natgateway" {
  source  = "Azure/avm-res-network-natgateway/azurerm"
  version = "0.2.1"

  location            = azapi_resource.this_rg.location
  name                = module.naming.nat_gateway.name_unique
  resource_group_name = azapi_resource.this_rg.name
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
  location            = azapi_resource.this_rg.location
  resource_group_name = azapi_resource.this_rg.name
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

resource "random_password" "admin_password" {
  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
  special          = true
}

module "testvm" {
  source = "../../"

  location            = azapi_resource.this_rg.location
  name                = module.naming.virtual_machine.name_unique
  resource_group_name = azapi_resource.this_rg.name
  zone                = random_integer.zone_index.result
  account_credentials = {
    admin_credentials = {
      username                           = "testuser"
      password                           = random_password.admin_password.result
      generate_admin_password_or_ssh_key = false
    }
  }
  enable_telemetry = var.enable_telemetry
  extensions = {
    # The regression guard. `commandToExecute` is supplied ONLY through
    # protected_settings, so the handler has nothing to run and the apply fails
    # outright if the module ever stops delivering protectedSettings to Azure.
    # Azure never returns protectedSettings, so a silent drop is invisible to an
    # idempotency check - the extension has to fail for the test to catch it,
    # which is why failure_suppression_enabled stays false.
    #
    # `settings` is populated at the same time on purpose: protected and public
    # settings share one `properties` object, so this also proves that carrying
    # the secret does not strip its non-sensitive siblings.
    custom_script_protected_settings = {
      name                        = "CustomScriptExtension"
      failure_suppression_enabled = false
      publisher                   = "Microsoft.Compute"
      type                        = "CustomScriptExtension"
      type_handler_version        = "1.10"

      settings = jsonencode(
        {
          timestamp = 1
        }
      )

      protected_settings = jsonencode(
        {
          commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -Command \"Set-Content -Path C:\\AzureData\\avm-protected-settings-proof.txt -Value delivered\""
        }
      )
    }
    # A sibling with public settings and no protected settings at all. Both
    # extensions come from the same `extensions` map, so this fails if the
    # module ever builds a protected-settings payload unconditionally rather
    # than only for the extensions that actually supply one.
    bginfo_public_settings_only = {
      name                 = "BGInfo"
      publisher            = "Microsoft.Compute"
      type                 = "BGInfo"
      type_handler_version = "2.1"

      settings = jsonencode(
        {
          Properties = []
        }
      )
    }
  }
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
  sku_size = module.vm_sku.sku
  tags     = local.tags
}
