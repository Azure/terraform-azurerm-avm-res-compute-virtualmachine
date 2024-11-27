terraform {
  required_version = "~> 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
  version = "~> 0.4"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.3.0"

  availability_zones_filter = true
}

locals {
  #deployment_region = module.regions.regions[random_integer.region_index.result].name
  deployment_region = "canadacentral" #temporarily pinning on single region 
  tags = {
    scenario = "Default"
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

module "get_valid_sku_for_deployment_region" {
  source = "../../modules/sku_selector"

  deployment_region = local.deployment_region
}

resource "azurerm_resource_group" "this_rg" {
  location = local.deployment_region
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}

resource "azurerm_virtual_network" "this_vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

resource "azurerm_subnet" "this_subnet_1" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "${module.naming.subnet.name_unique}-1"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}

resource "azurerm_subnet" "this_subnet_lb" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "${module.naming.subnet.name_unique}-lb"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}

resource "azurerm_subnet" "this_subnet_2" {
  address_prefixes     = ["10.0.3.0/24"]
  name                 = "${module.naming.subnet.name_unique}-2"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}


# Uncomment this section if you would like to include a bastion resource with this example.
resource "azurerm_subnet" "bastion_subnet" {
  address_prefixes     = ["10.0.4.0/24"]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}

resource "azurerm_public_ip" "bastionpip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.bastion_host.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name

  ip_configuration {
    name                 = "${module.naming.bastion_host.name_unique}-ipconf"
    public_ip_address_id = azurerm_public_ip.bastionpip.id
    subnet_id            = azurerm_subnet.bastion_subnet.id
  }
}


data "azurerm_client_config" "current" {}

module "avm_res_keyvault_vault" {
  source                      = "Azure/avm-res-keyvault-vault/azurerm"
  version                     = "=0.9.1"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  name                        = module.naming.key_vault.name_unique
  resource_group_name         = azurerm_resource_group.this_rg.name
  location                    = azurerm_resource_group.this_rg.location
  enabled_for_disk_encryption = true
  network_acls = {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  role_assignments = {
    deployment_user_secrets = { #give the deployment user access to secrets
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }

  tags = local.tags
}

resource "azurerm_storage_account" "app_account" {
  account_replication_type = "ZRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this_rg.location
  name                     = module.naming.storage_account.name_unique
  resource_group_name      = azurerm_resource_group.this_rg.name
}

resource "azurerm_storage_container" "app_container" {
  name                  = module.naming.storage_container.name_unique
  storage_account_name  = azurerm_storage_account.app_account.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "app" {
  name                   = "install-script.ps1"
  storage_account_name   = azurerm_storage_account.app_account.name
  storage_container_name = azurerm_storage_container.app_container.name
  type                   = "Block"
  source                 = "${path.module}/install-vscode.ps1"
}

#blob content = file


resource "azurerm_shared_image_gallery" "app_gallery" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.shared_image_gallery.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

resource "azurerm_gallery_application" "app_gallery_sample" {
  gallery_id        = azurerm_shared_image_gallery.app_gallery.id
  location          = azurerm_resource_group.this_rg.location
  name              = "VSCode"
  supported_os_type = "Windows"
}

resource "azurerm_gallery_application_version" "test_app_version" {
  gallery_application_id = azurerm_gallery_application.app_gallery_sample.id
  location               = azurerm_gallery_application.app_gallery_sample.location
  name                   = "0.1.0"
  package_file           = "install-script.ps1"

  manage_action {
    install = "powershell.exe -command ./install-script.ps1"
    remove  = "powershell.exe -command ./install-script.ps1 -mode uninstall"
  }
  source {
    media_link = azurerm_storage_blob.app.id
  }
  target_region {
    name                   = azurerm_gallery_application.app_gallery_sample.location
    regional_replica_count = 1
  }
}

resource "azurerm_recovery_services_vault" "test_vault" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.recovery_services_vault.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  sku                 = "Standard"
  soft_delete_enabled = false
  storage_mode_type   = "LocallyRedundant"
}

resource "azurerm_backup_policy_vm" "test_policy" {
  name                = "${module.naming.recovery_services_vault.name_unique}-test-policy"
  recovery_vault_name = azurerm_recovery_services_vault.test_vault.name
  resource_group_name = azurerm_resource_group.this_rg.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 10
  }
}

resource "azurerm_maintenance_configuration" "test_maintenance_config" {
  location                 = azurerm_resource_group.this_rg.location
  name                     = "${module.naming.virtual_machine.name_unique}-test-maint-config"
  resource_group_name      = azurerm_resource_group.this_rg.name
  scope                    = "InGuestPatch"
  in_guest_user_patch_mode = "User"

  install_patches {
    reboot = "Always"

    windows {
      classifications_to_include = ["Critical", "Security", "UpdateRollup"]
    }
  }
  window {
    start_date_time = formatdate("YYYY-MM-DD hh:mm", timeadd(timestamp(), "30m"))
    time_zone       = "Pacific Standard Time"
    duration        = "04:00"
    recur_every     = "Month Second Friday"
  }

  lifecycle {
    ignore_changes = [window[0].start_date_time]
  }
}

module "testvm" {
  source = "../../"
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.17.0

  enable_telemetry    = var.enable_telemetry
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  os_type             = "Windows"
  name                = module.naming.virtual_machine.name_unique
  #admin_credential_key_vault_resource_id                 = module.avm_res_keyvault_vault.resource_id
  sku_size                                               = module.get_valid_sku_for_deployment_region.sku
  encryption_at_host_enabled                             = true
  zone                                                   = random_integer.zone_index.result
  patch_assessment_mode                                  = "AutomaticByPlatform"
  patch_mode                                             = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true

  generated_secrets_key_vault_secret_config = {
    key_vault_resource_id = module.avm_res_keyvault_vault.resource_id
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = azurerm_subnet.this_subnet_1.id
        }
      }
      role_assignments = {
        role_assignment_1 = {
          principal_id               = data.azurerm_client_config.current.client_id
          role_definition_id_or_name = "Contributor"
          description                = "Assign the Contributor role to the deployment user on this network interface resource scope."
          principal_type             = "ServicePrincipal"
        }
      }
    }
  }

  gallery_applications = {
    vscode = {
      version_id = azurerm_gallery_application_version.test_app_version.id
      order      = 1
    }
  }

  azure_backup_configurations = {
    backup_config = {
      resource_group_name       = azurerm_recovery_services_vault.test_vault.resource_group_name
      recovery_vault_name       = azurerm_recovery_services_vault.test_vault.name
      backup_policy_resource_id = azurerm_backup_policy_vm.test_policy.id
    }
  }

  maintenance_configuration_resource_ids = {
    config_1 = azurerm_maintenance_configuration.test_maintenance_config.id
  }

  tags = local.tags

  depends_on = [module.avm_res_keyvault_vault]

}
