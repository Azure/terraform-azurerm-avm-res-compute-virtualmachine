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
      purge_soft_delete_on_destroy = true
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
  version = "=0.8.1"

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

/* Uncomment this section if you would like to include a bastion resource with this example.
resource "azurerm_public_ip" "bastionpip" {
  name                = module.naming.public_ip.name_unique
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = module.naming.bastion_host.name_unique
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name

  ip_configuration {
    name                 = "${module.naming.bastion_host.name_unique}-ipconf"
    subnet_id            = module.vnet.subnets["AzureBastionSubnet"].resource_id
    public_ip_address_id = azurerm_public_ip.bastionpip.id
  }
}
*/


data "azurerm_client_config" "current" {}

resource "random_password" "admin_password" {
  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
  special          = true
}

module "avm_res_keyvault_vault" {
  source                      = "Azure/avm-res-keyvault-vault/azurerm"
  version                     = "=0.10.0"
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

resource "azurerm_orchestrated_virtual_machine_scale_set" "this" {
  location                    = azurerm_resource_group.this_rg.location
  name                        = module.naming.virtual_machine_scale_set.name_unique
  platform_fault_domain_count = 1
  resource_group_name         = azurerm_resource_group.this_rg.name
  zones                       = ["1", "2", "3"]
}

module "testvm" {
  source = "../../"
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.13.0"

  admin_username                        = "azureuser"
  admin_password                        = random_password.admin_password.result
  disable_password_authentication       = false
  enable_telemetry                      = var.enable_telemetry
  encryption_at_host_enabled            = true
  generate_admin_password_or_ssh_key    = false
  location                              = azurerm_resource_group.this_rg.location
  name                                  = module.naming.virtual_machine.name_unique
  resource_group_name                   = azurerm_resource_group.this_rg.name
  os_type                               = "Linux"
  sku_size                              = module.vm_sku.sku
  virtual_machine_scale_set_resource_id = azurerm_orchestrated_virtual_machine_scale_set.this.id
  zone                                  = random_integer.zone_index.result

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

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  tags = local.tags

  depends_on = [
    azurerm_orchestrated_virtual_machine_scale_set.this
  ]
}

module "testvm2" {
  source = "../../"
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.19.0"

  enable_telemetry                      = var.enable_telemetry
  encryption_at_host_enabled            = true
  location                              = azurerm_resource_group.this_rg.location
  name                                  = "${module.naming.virtual_machine.name_unique}-01"
  resource_group_name                   = azurerm_resource_group.this_rg.name
  os_type                               = "Linux"
  sku_size                              = module.vm_sku.sku
  virtual_machine_scale_set_resource_id = azurerm_orchestrated_virtual_machine_scale_set.this.id
  zone                                  = random_integer.zone_index.result

  account_credentials = {
    admin_credentials = {
      username                           = "testuser"
      password                           = random_password.admin_password.result
      generate_admin_password_or_ssh_key = false
    }
    password_authentication_disabled = false
  }

  network_interfaces = {
    network_interface_1 = {
      name = "${module.naming.network_interface.name_unique}-01"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-01-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  tags = local.tags

  depends_on = [
    azurerm_orchestrated_virtual_machine_scale_set.this
  ]
}
