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
  version = "=0.15.0"

  location      = azurerm_resource_group.this_rg.location
  parent_id     = azurerm_resource_group.this_rg.id
  address_space = ["10.0.0.0/16"]
  name          = module.naming.virtual_network.name_unique
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
      address_prefixes = ["10.0.3.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
      delegations = [{
        name = "Microsoft.Network.applicationGateways"
        service_delegation = {
          name = "Microsoft.Network/applicationGateways"
        }
      }]
    }
    lb_subnet_1 = {
      name             = "${module.naming.subnet.name_unique}-lb"
      address_prefixes = ["10.0.2.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.4.0/24"]
    }
  }
}


/*
# Uncomment this section if you would like to include a bastion resource with this example.
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

module "loadbalancer" {
  source  = "Azure/avm-res-network-loadbalancer/azurerm"
  version = "0.3.2"

  # Frontend IP Configuration
  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = "testFrontend"
    }
  }
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.lb.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  # Backend Address Pool
  backend_address_pools = {
    pool_1 = {
      name = "testBackendPool"
    }
  }
  enable_telemetry = var.enable_telemetry
  # Virtual Network and Subnet for Internal LoadBalancer
  # frontend_vnet_resource_id   = azurerm_virtual_network.example.id
  frontend_subnet_resource_id = module.vnet.subnets["lb_subnet_1"].resource_id
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
  app_gw_public_ip_name          = "${module.vnet.name}-pip"
  backend_address_pool_name      = "${module.vnet.name}-beap"
  frontend_ip_configuration_name = "${module.vnet.name}-feip"
  frontend_port_name             = "${module.vnet.name}-feport"
  http_setting_name              = "${module.vnet.name}-be-htst"
  listener_name                  = "${module.vnet.name}-httplstn"
  request_routing_rule_name      = "${module.vnet.name}-rqrt"
}

resource "azurerm_public_ip" "app_gw_pip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this_rg.location
  name                = local.app_gw_public_ip_name
  resource_group_name = azurerm_resource_group.this_rg.name
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_application_gateway" "network" {
  location            = azurerm_resource_group.this_rg.location
  name                = "example-appgateway"
  resource_group_name = azurerm_resource_group.this_rg.name
  zones               = ["1", "2", "3"]

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
    subnet_id = module.vnet.subnets["vm_subnet_2"].resource_id
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
    name = "Standard_v2"
    tier = "Standard_v2"
  }
  autoscale_configuration {
    min_capacity = 2
    max_capacity = 5
  }
}

data "azurerm_client_config" "current" {}

module "avm_res_keyvault_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "=0.10.0"

  location                    = azurerm_resource_group.this_rg.location
  name                        = "${module.naming.key_vault.name_unique}-win-alb"
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

module "testnsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.1.1"

  location = azurerm_resource_group.this_rg.location
  name     = module.naming.network_security_group.name_unique
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
  resource_group_name = azurerm_resource_group.this_rg.name
  enable_telemetry    = var.enable_telemetry
}

resource "azurerm_application_security_group" "test_asg" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.application_security_group.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
}


module "testvm" {
  source = "../../"

  location = azurerm_resource_group.this_rg.location
  name     = module.naming.virtual_machine.name_unique
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
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
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
  enable_telemetry           = var.enable_telemetry
  encryption_at_host_enabled = true
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  os_type  = "Windows"
  sku_size = module.vm_sku.sku
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
  tags = local.tags

  depends_on = [module.avm_res_keyvault_vault, module.testnsg, module.loadbalancer, azurerm_application_security_group.test_asg, azurerm_application_gateway.network] #setting explicit dependencies to enforce destroy ordering
}
