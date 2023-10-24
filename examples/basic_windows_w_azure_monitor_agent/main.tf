terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

# This picks a random region from the list of regions.
resource "random_integer" "region_index" {
  min = 0
  max = length(local.azure_regions) - 1
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

provider "azurerm" {
  features {}
}

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this_rg" {
  name     = module.naming.resource_group.name_unique
  location = local.azure_regions[random_integer.region_index.result]
}

# Create a virtual network and subnets for the deployment
resource "azurerm_virtual_network" "this_vnet" {
  name                = module.naming.virtual_network.name_unique
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
}

resource "azurerm_subnet" "this_subnet_1" {
  name                 = "${module.naming.subnet.name_unique}-1"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "this_subnet_2" {
  name                 = "${module.naming.subnet.name_unique}-2"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

data "azurerm_client_config" "current" {}

#create a keyvault for storing the credential with RBAC for the deployment user
module "avm-res-keyvault-vault" {
  source              = "Azure/avm-res-keyvault-vault/azurerm"
  version             = "0.3.0"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  name                = module.naming.key_vault.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  location            = azurerm_resource_group.this_rg.location
  network_acls = {
    default_action = "Allow"
  }

  role_assignments = {
    deployment_user_secrets = {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }
}

#create a log analytics workspace as a diag settings and/or AMA destination.
resource "azurerm_log_analytics_workspace" "this_workspace" {
  name                = module.naming.log_analytics_workspace.name_unique
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}


#create the virtual machine
module "testvm" {
  source = "../../"

  resource_group_name                    = azurerm_resource_group.this_rg.name
  virtualmachine_os_type                 = "Windows"
  name                                   = module.naming.virtual_machine.name_unique
  admin_credential_key_vault_resource_id = module.avm-res-keyvault-vault.resource.id

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  managed_identities = {
    system_assigned = true
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

      diagnostic_settings = {
        nic_diags = {
          name                  = module.naming.monitor_diagnostic_setting.name_unique
          workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }

  diagnostic_settings = {
    vm_diags = {
      name                  = module.naming.monitor_diagnostic_setting.name_unique
      workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id
      metric_categories     = ["AllMetrics"]
    }
  }

  depends_on = [
    module.avm-res-keyvault-vault
  ]
}

resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {

  name                       = "${module.testvm.virtual_machine.name}-azure-monitor-agent"
  virtual_machine_id         = module.testvm.virtual_machine.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  settings                   = null #var.azure_monitor_agent_extension_settings.managed_identity_type == "UserAssigned" ? jsonencode(local.azure_monitor_agent_authentication_user_assigned_identity_settings) : null
}

data "azuread_client_config" "current" {}

resource "azurerm_monitor_data_collection_rule" "test" {
  name                = "${module.testvm.virtual_machine.name}-dce"
  resource_group_name = azurerm_resource_group.this_rg.name
  location            = azurerm_resource_group.this_rg.location
  destinations {
    azure_monitor_metrics {
      name = "example-destination-metrics"
    }

    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id
      name                  = "log-analytics"
    }
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["example-destination-metrics", "log-analytics"]
  }
}

resource "azurerm_monitor_data_collection_endpoint" "test" {
  name                = "${module.testvm.virtual_machine.name}-dce"
  resource_group_name = azurerm_resource_group.this_rg.name
  location            = azurerm_resource_group.this_rg.location
}

# associate to a Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "this_endpoint" {

  name                    = "${azurerm_monitor_data_collection_rule.test.name}-association"
  target_resource_id      = module.testvm.virtual_machine.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.test.id
  description             = "test data collection rule association"
}

# associate to a Data Collection Endpoint
resource "azurerm_monitor_data_collection_rule_association" "this" {

  target_resource_id          = module.testvm.virtual_machine.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.test.id
  description                 = "test data collection endpoint association"
}

output "vm" {
  value     = module.testvm.virtual_machine
  sensitive = true
}
