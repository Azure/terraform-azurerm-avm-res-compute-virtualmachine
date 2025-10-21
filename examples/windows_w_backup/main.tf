terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
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
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
    recovery_service {
      vm_backup_stop_protection_and_retain_data_on_destroy = false
      purge_protected_items_from_vault_on_destroy          = true
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
  deployment_region = "canadacentral"
  tags = {
    scenario = "Backup example"
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
  count = 2

  location = local.deployment_region
  name     = "${module.naming.resource_group.name_unique}-${count.index + 1}"
  tags     = local.tags
}


module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = azurerm_resource_group.this_rg[0].location
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

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "=0.8.1"

  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this_rg[0].location
  resource_group_name = azurerm_resource_group.this_rg[0].name
  name                = module.naming.virtual_network.name_unique
  subnets = {
    vm_subnet_1 = {
      name             = "${module.naming.subnet.name_unique}-1"
      address_prefixes = ["10.0.1.0/24"]
    }
    vm_subnet_2 = {
      name             = "${module.naming.subnet.name_unique}-2"
      address_prefixes = ["10.0.2.0/24"]
    }
  }
}

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this_rg[0].location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg[0].name
  tags                = local.tags
}

resource "azurerm_recovery_services_vault" "test_vault" {
  location            = azurerm_resource_group.this_rg[1].location
  name                = module.naming.recovery_services_vault.name_unique
  resource_group_name = azurerm_resource_group.this_rg[1].name
  sku                 = "Standard"
  soft_delete_enabled = false
  storage_mode_type   = "LocallyRedundant"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_backup_policy_vm" "test_policy" {
  name                = "${module.naming.recovery_services_vault.name_unique}-test-policy"
  recovery_vault_name = azurerm_recovery_services_vault.test_vault.name
  resource_group_name = azurerm_resource_group.this_rg[1].name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 10
  }

  depends_on = [azurerm_recovery_services_vault.test_vault]
}

module "testvm" {
  source = "../../"

  location = azurerm_resource_group.this_rg[0].location
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
  resource_group_name = azurerm_resource_group.this_rg[0].name
  zone                = random_integer.zone_index.result
  azure_backup_configurations = {
    arbitrary_key = {
      recovery_vault_resource_id = azurerm_recovery_services_vault.test_vault.id
      backup_policy_resource_id  = azurerm_backup_policy_vm.test_policy.id
    }
  }
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  enable_telemetry                                       = var.enable_telemetry
  encryption_at_host_enabled                             = false
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }
  os_type               = "Windows"
  patch_assessment_mode = "AutomaticByPlatform"
  patch_mode            = "AutomaticByPlatform"
  sku_size              = module.vm_sku.sku
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
  tags = {
    scenario = "windows_w_azure_monitor_agent"
  }

  depends_on = [
    azurerm_backup_policy_vm.test_policy,
    azurerm_recovery_services_vault.test_vault
  ]
}
