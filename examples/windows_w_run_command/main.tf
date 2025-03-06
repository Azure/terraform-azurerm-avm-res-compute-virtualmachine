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
    scenario = "Run Command"
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
  version = "0.2.0"

  name                = module.naming.nat_gateway.name_unique
  enable_telemetry    = true
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name

  public_ips = {
    public_ip_1 = {
      name = "nat_gw_pip1"
    }
  }
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "=0.7.1"

  resource_group_name = azurerm_resource_group.this_rg.name
  address_space       = ["10.0.0.0/16"]
  name                = module.naming.virtual_network.name_unique
  location            = azurerm_resource_group.this_rg.location

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

/*
#uncomment this block to enable bastion host
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

  wait_for_rbac_before_key_operations = {
    create = "60s"
  }

  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }

  tags = local.tags

  secrets = {
    admin_password = {
      name = "admin-password"
    }
  }

  secrets_value = {
    admin_password = random_password.admin_password.result
  }
}

resource "random_string" "name_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_storage_account" "this" {
  account_replication_type = "ZRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this_rg.location
  name                     = "avmstorage${random_string.name_suffix.result}"
  resource_group_name      = azurerm_resource_group.this_rg.name
}

resource "azurerm_storage_container" "this" {
  name                  = "example-sc"
  container_access_type = "blob"
  storage_account_name  = azurerm_storage_account.this.name
}

resource "azurerm_storage_blob" "example1" {
  name                   = "script1"
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.this.name
  type                   = "Block"
  source_content         = "echo hello world"
}

resource "azurerm_storage_blob" "example2" {
  name                   = "output"
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.this.name
  type                   = "Append"
}

resource "azurerm_storage_blob" "example3" {
  name                   = "error"
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.this.name
  type                   = "Append"
}

resource "azurerm_role_assignment" "this" {
  principal_id         = azurerm_user_assigned_identity.example_identity.principal_id
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
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
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.17.0

  admin_username                     = "azureuser"
  admin_password                     = random_password.admin_password.result
  generate_admin_password_or_ssh_key = false
  enable_telemetry                   = var.enable_telemetry
  location                           = azurerm_resource_group.this_rg.location
  resource_group_name                = azurerm_resource_group.this_rg.name
  os_type                            = "Windows"
  name                               = module.naming.virtual_machine.name_unique
  sku_size                           = module.vm_sku.sku
  encryption_at_host_enabled         = true
  zone                               = random_integer.zone_index.result

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
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

  run_commands = {
    test_example_simple = {
      location = azurerm_resource_group.this_rg.location
      name     = "example-command"
      script_source = {
        script = "echo Hello World"
      }

      tags = local.tags
    }

    test_example_from_storage = {
      location        = azurerm_resource_group.this_rg.location
      name            = "example-command-storage"
      error_blob_uri  = azurerm_storage_blob.example3.url
      output_blob_uri = azurerm_storage_blob.example2.url
      script_source = {
        script_uri = azurerm_storage_blob.example1.url
      }

      error_blob_managed_identity = {
        client_id = azurerm_user_assigned_identity.example_identity.client_id
      }

      output_blob_managed_identity = {
        client_id = azurerm_user_assigned_identity.example_identity.client_id
      }

      tags = local.tags
    }
  }

  run_commands_secrets = {
    test_example_from_storage = {
      run_as_password = random_password.admin_password.result
      run_as_user     = "azureuser"
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

  tags = local.tags

  depends_on = [module.avm_res_keyvault_vault, azurerm_user_assigned_identity.example_identity, azurerm_role_assignment.this]

}
