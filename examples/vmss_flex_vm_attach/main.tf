module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = "=0.8.1"
}

locals {
  tags = {
    scenario = "common_centos_with_plaintext_password"
  }
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions_by_name) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[module.regions.regions[random_integer.region_index.result].name].zones)
  min = 1
}

module "get_valid_sku_for_deployment_region" {
  source = "../../modules/sku_selector"

  deployment_region = module.regions.regions[random_integer.region_index.result].name
}

resource "azurerm_resource_group" "this_rg" {
  location = module.regions.regions[random_integer.region_index.result].name
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

resource "azurerm_subnet" "this_subnet_2" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "${module.naming.subnet.name_unique}-2"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}

/* Uncomment this section if you would like to include a bastion resource with this example.
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

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
    subnet_id            = azurerm_subnet.bastion_subnet.id
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
  version                     = "=0.7.1"
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
  sku_size                              = module.get_valid_sku_for_deployment_region.sku
  virtual_machine_scale_set_resource_id = azurerm_orchestrated_virtual_machine_scale_set.this.id
  zone                                  = random_integer.zone_index.result

  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = azurerm_subnet.this_subnet_1.id
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
  #version = "0.15.1"

  admin_username                        = "azureuser"
  admin_password                        = random_password.admin_password.result
  disable_password_authentication       = false
  enable_telemetry                      = var.enable_telemetry
  encryption_at_host_enabled            = true
  generate_admin_password_or_ssh_key    = false
  location                              = azurerm_resource_group.this_rg.location
  name                                  = "${module.naming.virtual_machine.name_unique}-01"
  resource_group_name                   = azurerm_resource_group.this_rg.name
  os_type                               = "Linux"
  sku_size                              = module.get_valid_sku_for_deployment_region.sku
  virtual_machine_scale_set_resource_id = azurerm_orchestrated_virtual_machine_scale_set.this.id
  zone                                  = random_integer.zone_index.result

  network_interfaces = {
    network_interface_1 = {
      name = "${module.naming.network_interface.name_unique}-01"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-01-ipconfig1"
          private_ip_subnet_resource_id = azurerm_subnet.this_subnet_1.id
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