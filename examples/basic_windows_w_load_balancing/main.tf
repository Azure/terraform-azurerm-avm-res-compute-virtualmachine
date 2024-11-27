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

/*
# Uncomment this section if you would like to include a bastion resource with this example.
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

module "loadbalancer" {
  source  = "Azure/avm-res-network-loadbalancer/azurerm"
  version = "0.1.7"

  enable_telemetry = var.enable_telemetry

  name                = module.naming.lb.name_unique
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name

  # Virtual Network and Subnet for Internal LoadBalancer
  # frontend_vnet_resource_id   = azurerm_virtual_network.example.id
  frontend_subnet_resource_id = azurerm_subnet.this_subnet_lb.id

  # Frontend IP Configuration
  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = "testFrontend"
    }
  }

  # Backend Address Pool
  backend_address_pools = {
    pool_1 = {
      name = "testBackendPool"
    }
  }

  lb_nat_rules = {
    lb_nat_rule_1 = {
      name                           = "rdp_nat_rule_1"
      frontend_ip_configuration_name = "testFrontend"
      protocol                       = "Tcp"
      frontend_port                  = 30001
      backend_port                   = 3389
    }
  }
}

# copied over from the AzureRM example - simplifies naming for the appgw resources
locals {
  app_gw_public_ip_name          = "${azurerm_virtual_network.this_vnet.name}-pip"
  backend_address_pool_name      = "${azurerm_virtual_network.this_vnet.name}-beap"
  frontend_ip_configuration_name = "${azurerm_virtual_network.this_vnet.name}-feip"
  frontend_port_name             = "${azurerm_virtual_network.this_vnet.name}-feport"
  http_setting_name              = "${azurerm_virtual_network.this_vnet.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.this_vnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.this_vnet.name}-rqrt"
}

resource "azurerm_public_ip" "app_gw_pip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this_rg.location
  name                = local.app_gw_public_ip_name
  resource_group_name = azurerm_resource_group.this_rg.name
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "network" {
  location            = azurerm_resource_group.this_rg.location
  name                = "example-appgateway"
  resource_group_name = azurerm_resource_group.this_rg.name

  backend_address_pool {
    name = local.backend_address_pool_name
  }
  backend_http_settings {
    cookie_based_affinity = "Disabled"
    name                  = local.http_setting_name
    port                  = 80
    protocol              = "Http"
    path                  = "/path1/"
    request_timeout       = 60
  }
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.app_gw_pip.id
  }
  frontend_port {
    name = local.frontend_port_name
    port = 80
  }
  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.this_subnet_2.id
  }
  http_listener {
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    name                           = local.listener_name
    protocol                       = "Http"
  }
  request_routing_rule {
    http_listener_name         = local.listener_name
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 9
  }
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
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

module "testnsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.1.1"

  enable_telemetry    = var.enable_telemetry
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  name                = module.naming.network_security_group.name_unique
  nsgrules = { #allow all just to show the association.
    "rule01" : {
      "nsg_rule_access" : "Allow",
      "nsg_rule_destination_address_prefix" : "*",
      "nsg_rule_destination_port_range" : "*",
      "nsg_rule_direction" : "Inbound",
      "nsg_rule_priority" : 100,
      "nsg_rule_protocol" : "Tcp",
      "nsg_rule_source_address_prefix" : "*",
      "nsg_rule_source_port_range" : "*"
    },
    "rule02" : {
      "nsg_rule_access" : "Allow",
      "nsg_rule_destination_address_prefix" : "*",
      "nsg_rule_destination_port_range" : "*",
      "nsg_rule_direction" : "Outbound",
      "nsg_rule_priority" : 200,
      "nsg_rule_protocol" : "Tcp",
      "nsg_rule_source_address_prefix" : "*",
      "nsg_rule_source_port_range" : "*"
    }
  }
}

resource "azurerm_application_security_group" "test_asg" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.application_security_group.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
}


module "testvm" {
  source = "../../"
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.17.0

  enable_telemetry           = var.enable_telemetry
  location                   = azurerm_resource_group.this_rg.location
  resource_group_name        = azurerm_resource_group.this_rg.name
  os_type                    = "Windows"
  name                       = module.naming.virtual_machine.name_unique
  sku_size                   = module.get_valid_sku_for_deployment_region.sku
  encryption_at_host_enabled = true
  zone                       = random_integer.zone_index.result

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
      application_security_groups = {
        asg_1 = {
          application_security_group_resource_id = azurerm_application_security_group.test_asg.id
        }
      }
      network_security_groups = {
        nsg_1 = {
          network_security_group_resource_id = module.testnsg.nsg_resource.id
        }
      }
      ip_configurations = {
        ip_configuration_1 = {
          app_gateway_backend_pools = {
            app_gw_pool_1 = {
              app_gateway_backend_pool_resource_id = [for value in azurerm_application_gateway.network.backend_address_pool : value.id if value.name == local.backend_address_pool_name][0]
            }
          }
          load_balancer_backend_pools = {
            lb_pool_1 = {
              load_balancer_backend_pool_resource_id = module.loadbalancer.azurerm_lb_backend_address_pool["pool_1"].id
            }
          }
          load_balancer_nat_rules = {
            lb_nat_rule_1 = {
              load_balancer_nat_rule_resource_id = module.loadbalancer.azurerm_lb_nat_rule["rdp_nat_rule_1"].id
            }
          }
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = azurerm_subnet.this_subnet_1.id
        }
      }
    }
  }

  tags = local.tags

  depends_on = [module.avm_res_keyvault_vault, module.testnsg, module.loadbalancer, azurerm_application_security_group.test_asg, azurerm_application_gateway.network] #setting explicit dependencies to enforce destroy ordering

}
