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
  version = "~> 0.4"
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
    vm_subnet_2 = {
      name             = "${module.naming.subnet.name_unique}-2"
      address_prefixes = ["10.0.2.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.3.0/24"]
    }
  }
}

/* #uncomment these resources to enable bastion
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
    subnet_id            = module.vnet.subnets["AzureBastionSubnet"].resource_id
  }
}
*/

data "azurerm_client_config" "current" {}

module "avm_res_keyvault_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "=0.10.0"

  location                    = azurerm_resource_group.this_rg.location
  name                        = "${module.naming.key_vault.name_unique}-gallery"
  resource_group_name         = azurerm_resource_group.this_rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
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
  tags = local.tags
  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }
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
  container_access_type = "blob"
  storage_account_id    = azurerm_storage_account.app_account.id
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

resource "azurerm_resource_group" "rsv_rg" {
  location = local.deployment_region
  name     = "${module.naming.resource_group.name_unique}-RSV-rg"
  tags     = local.tags
}

resource "azurerm_recovery_services_vault" "test_vault" {
  location            = azurerm_resource_group.rsv_rg.location
  name                = module.naming.recovery_services_vault.name_unique
  resource_group_name = azurerm_resource_group.rsv_rg.name
  sku                 = "Standard"
  soft_delete_enabled = false
  storage_mode_type   = "LocallyRedundant"
}

resource "azurerm_backup_policy_vm" "test_policy" {
  name                = "${module.naming.recovery_services_vault.name_unique}-test-policy"
  recovery_vault_name = azurerm_recovery_services_vault.test_vault.name
  resource_group_name = azurerm_resource_group.rsv_rg.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }
  retention_daily {
    count = 10
  }

  depends_on = [azurerm_recovery_services_vault.test_vault]
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
  resource_group_name = azurerm_resource_group.this_rg.name
  zone                = random_integer.zone_index.result
  account_credentials = {
    key_vault_configuration = {
      resource_id = module.avm_res_keyvault_vault.resource_id
    }
  }
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  data_disk_managed_disks = {
    disk1 = {
      name                 = "${module.naming.managed_disk.name_unique}-lun0"
      storage_account_type = "Premium_LRS"
      lun                  = 0
      caching              = "ReadWrite"
      disk_size_gb         = 32
    }
  }
  enable_telemetry           = var.enable_telemetry
  encryption_at_host_enabled = true
  gallery_applications = {
    vscode = {
      version_id = azurerm_gallery_application_version.test_app_version.id
      order      = 1
    }
  }
  maintenance_configuration_resource_ids = {
    config_1 = azurerm_maintenance_configuration.test_maintenance_config.id
  }
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
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
  tags = local.tags

  depends_on = [
    module.avm_res_keyvault_vault,
    azurerm_backup_policy_vm.test_policy,
    azurerm_recovery_services_vault.test_vault
  ]
}
