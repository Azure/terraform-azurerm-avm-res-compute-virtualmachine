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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
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
  location = local.deployment_region
  name     = "${module.naming.resource_group.name_unique}"
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
    }
    vm_subnet_2 = {
      name             = "${module.naming.subnet.name_unique}-2"
      address_prefixes = ["10.0.2.0/24"]
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

data "azuread_service_principal" "backup_service_app" {
  display_name = "Backup Management Service"
}


module "avm_res_keyvault_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "=0.10.0"

  location                    = azurerm_resource_group.this_rg.location
  name                        = "${module.naming.key_vault.name_unique}-waf"
  resource_group_name         = azurerm_resource_group.this_rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  network_acls = {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
  role_assignments = {
    deployment_user_secrets = {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = data.azurerm_client_config.current.object_id
    }
    vm_identity = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = azurerm_user_assigned_identity.example_identity.principal_id
    }
  }
  tags = local.tags
  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }
}

# Introduce an explicit delay after Key Vault deployment to allow for RBAC/replication propagation
resource "time_sleep" "after_key_vault" {
  depends_on      = [module.avm_res_keyvault_vault]
  create_duration = "60s"
}

data "azurerm_key_vault" "this" {
  name                = basename(module.avm_res_keyvault_vault.resource_id)
  resource_group_name = azurerm_resource_group.this_rg.name
}

module "avm-res-compute-virtualmachine" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.19.1"

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

  bypass_platform_safety_checks_on_user_schedule_enabled = true
  enable_telemetry                                       = var.enable_telemetry
  encryption_at_host_enabled                             = false
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }
  os_type               = "Linux"
  patch_assessment_mode = "AutomaticByPlatform"
  patch_mode            = "AutomaticByPlatform"
  sku_size              = module.vm_sku.sku
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  account_credentials = {
    admin_credentials = {
      username = "adminpa"
      generate_admin_password_or_ssh_key = true
    }
    key_vault_configuration = {
      resource_id = data.azurerm_key_vault.this.id
      name                  = var.nva.name
    }
    password_authentication_disabled = false
  }
  tags = {
    scenario = "windows_w_azure_monitor_agent"
  }

  # Ensure we wait for the post-Key Vault delay before creating the VM which depends on Key Vault access
  depends_on = [time_sleep.after_key_vault]
}

variable "nva" {
  description = "Network Virtual Appliance"
  type = object({
    name = string
  })
  default = {
    name = "nva-example"
  }
}
