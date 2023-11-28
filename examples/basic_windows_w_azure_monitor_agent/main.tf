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
    azapi = {
      source  = "Azure/azapi"
      version = ">=1.9.0"
    }
  }
}

#toggle telemetry on or off
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
  version = ">= 0.3.0"
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.4.0"
}

#seed the test regions 
locals {
  test_regions = ["centralus", "eastasia", "westus2", "eastus2", "westeurope", "japaneast"]
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  min = 0
  max = length(local.test_regions) - 1
}

resource "random_integer" "zone_index" {
  min = 1
  max = length(module.regions.regions_by_name[local.test_regions[random_integer.region_index.result]].zones)
}

### this segment of code gets valid vm skus for deployment in the current subscription
data "azurerm_subscription" "current" {
}

#get the full sku list (azapi doesn't currently have a good way to filter the api call)
data "azapi_resource_list" "example" {
  type                   = "Microsoft.Compute/skus@2021-07-01"
  parent_id              = data.azurerm_subscription.current.id
  response_export_values = ["*"]
}

locals {
  #filter the location output for the current region, virtual machine resources, and filter out entries that don't include the capabilities list
  location_valid_vms = [
    for location in jsondecode(data.azapi_resource_list.example.output).value : location
    if contains(location.locations, local.test_regions[random_integer.region_index.result]) && #if the sku location field matches the selected location
    length(location.restrictions) < 1 &&                                                       #and there are no restrictions on deploying the sku (i.e. allowed for deployment)
    location.resourceType == "virtualMachines" &&                                              #and the sku is a virtual machine
    !strcontains(location.name, "C") &&                                                        #no confidential vm skus
    !strcontains(location.name, "B") &&                                                        #no B skus
    try(location.capabilities, []) != []                                                       #avoid skus where the capabilities list isn't defined
  ]

  #filter the region virtual machines by desired capabilities (v1/v2 support, 2 cpu, and encryption at host)
  deploy_skus = [
    for sku in local.location_valid_vms : sku
    if length([
      for capability in sku.capabilities : capability
      if(capability.name == "HyperVGenerations" && capability.value == "V1,V2") ||
      (capability.name == "vCPUs" && capability.value == "2") ||
      (capability.name == "EncryptionAtHostSupported" && capability.value == "True") ||
      (capability.name == "CpuArchitectureType" && capability.value == "x64")
    ]) == 4
  ]
}

resource "random_integer" "deploy_sku" {
  min = 0
  max = length(local.deploy_skus) - 1
}

# This is required for resource modules
resource "azurerm_resource_group" "this_rg" {
  name     = module.naming.resource_group.name_unique
  location = local.test_regions[random_integer.region_index.result]
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

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
}

#create a keyvault for storing the credential with RBAC for the deployment user
module "avm-res-keyvault-vault" {
  source              = "Azure/avm-res-keyvault-vault/azurerm"
  version             = ">= 0.5.0"
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

  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }

  tags = {
    scenario = "windows_w_azure_monitor_agent"
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
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.1.0"

  resource_group_name                    = azurerm_resource_group.this_rg.name
  virtualmachine_os_type                 = "Windows"
  name                                   = module.naming.virtual_machine.name_unique
  admin_credential_key_vault_resource_id = module.avm-res-keyvault-vault.resource.id
  virtualmachine_sku_size                = local.deploy_skus[random_integer.deploy_sku.result].name
  zone                                   = random_integer.zone_index.result

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
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

  extensions = {
    azure_monitor_agent = {
      name                       = "${module.testvm.virtual_machine.name}-azure-monitor-agent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorWindowsAgent"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      automatic_upgrade_enabled  = true
      settings                   = null
    }
  }

  tags = {
    scenario = "windows_w_azure_monitor_agent"
  }

  depends_on = [
    module.avm-res-keyvault-vault
  ]
}

data "azuread_client_config" "current" {}

resource "azurerm_monitor_data_collection_rule" "test" {
  name                = "${module.testvm.virtual_machine.name}-dcr"
  resource_group_name = azurerm_resource_group.this_rg.name
  location            = azurerm_resource_group.this_rg.location
  data_sources {
    windows_event_log {
      streams = ["Microsoft-Event"]
      name    = "eventLogsDataSource"
      x_path_queries = ["Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        "Security!*[System[(band(Keywords,4503599627370496))]]",
      "System!*[System[(Level=1 or Level=2 or Level=3)]]"]
    }

    performance_counter {
      name                          = "exampleCounters"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]
      counter_specifiers = [
        "\\Processor Information(_Total)\\% Processor Time",
        "\\Processor Information(_Total)\\% Privileged Time",
        "\\Processor Information(_Total)\\% User Time",
        "\\Processor Information(_Total)\\Processor Frequency",
        "\\System\\Processes",
        "\\Process(_Total)\\Thread Count",
        "\\Process(_Total)\\Handle Count",
        "\\System\\System Up Time",
        "\\System\\Context Switches/sec",
        "\\System\\Processor Queue Length",
        "\\Memory\\% Committed Bytes In Use",
        "\\Memory\\Available Bytes",
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Committed Bytes",
        "\\Memory\\Cache Bytes",
        "\\Memory\\Pool Paged Bytes",
        "\\Memory\\Pool Nonpaged Bytes",
        "\\Memory\\Pages/sec",
        "\\Memory\\Page Faults/sec",
        "\\Process(_Total)\\Working Set",
        "\\Process(_Total)\\Working Set - Private",
        "\\LogicalDisk(_Total)\\% Disk Time",
        "\\LogicalDisk(_Total)\\% Disk Read Time",
        "\\LogicalDisk(_Total)\\% Disk Write Time",
        "\\LogicalDisk(_Total)\\% Idle Time",
        "\\LogicalDisk(_Total)\\Disk Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Read Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Write Bytes/sec",
        "\\LogicalDisk(_Total)\\Disk Transfers/sec",
        "\\LogicalDisk(_Total)\\Disk Reads/sec",
        "\\LogicalDisk(_Total)\\Disk Writes/sec",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
        "\\LogicalDisk(_Total)\\Avg. Disk Queue Length",
        "\\LogicalDisk(_Total)\\Avg. Disk Read Queue Length",
        "\\LogicalDisk(_Total)\\Avg. Disk Write Queue Length",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\LogicalDisk(_Total)\\Free Megabytes",
        "\\Network Interface(*)\\Bytes Total/sec",
        "\\Network Interface(*)\\Bytes Sent/sec",
        "\\Network Interface(*)\\Bytes Received/sec",
        "\\Network Interface(*)\\Packets/sec",
        "\\Network Interface(*)\\Packets Sent/sec",
        "\\Network Interface(*)\\Packets Received/sec",
        "\\Network Interface(*)\\Packets Outbound Errors",
        "\\Network Interface(*)\\Packets Received Errors",
        "Processor(*)\\% Processor Time",
        "Processor(*)\\% Idle Time",
        "Processor(*)\\% User Time",
        "Processor(*)\\% Nice Time",
        "Processor(*)\\% Privileged Time",
        "Processor(*)\\% IO Wait Time",
        "Processor(*)\\% Interrupt Time",
        "Processor(*)\\% DPC Time",
        "Memory(*)\\Available MBytes Memory",
        "Memory(*)\\% Available Memory",
        "Memory(*)\\Used Memory MBytes",
        "Memory(*)\\% Used Memory",
        "Memory(*)\\Pages/sec",
        "Memory(*)\\Page Reads/sec",
        "Memory(*)\\Page Writes/sec",
        "Memory(*)\\Available MBytes Swap",
        "Memory(*)\\% Available Swap Space",
        "Memory(*)\\Used MBytes Swap Space",
        "Memory(*)\\% Used Swap Space",
        "Process(*)\\Pct User Time",
        "Process(*)\\Pct Privileged Time",
        "Process(*)\\Used Memory",
        "Process(*)\\Virtual Shared Memory",
        "Logical Disk(*)\\% Free Inodes",
        "Logical Disk(*)\\% Used Inodes",
        "Logical Disk(*)\\Free Megabytes",
        "Logical Disk(*)\\% Free Space",
        "Logical Disk(*)\\% Used Space",
        "Logical Disk(*)\\Logical Disk Bytes/sec",
        "Logical Disk(*)\\Disk Read Bytes/sec",
        "Logical Disk(*)\\Disk Write Bytes/sec",
        "Logical Disk(*)\\Disk Transfers/sec",
        "Logical Disk(*)\\Disk Reads/sec",
        "Logical Disk(*)\\Disk Writes/sec",
        "Network(*)\\Total Bytes Transmitted",
        "Network(*)\\Total Bytes Received",
        "Network(*)\\Total Bytes",
        "Network(*)\\Total Packets Transmitted",
        "Network(*)\\Total Packets Received",
        "Network(*)\\Total Rx Errors",
        "Network(*)\\Total Tx Errors",
        "Network(*)\\Total Collisions",
        "System(*)\\Uptime",
        "System(*)\\Load1",
        "System(*)\\Load5",
        "System(*)\\Load15",
        "System(*)\\Users",
        "System(*)\\Unique Users",
        "System(*)\\CPUs",
        "\\PhysicalDisk(_Total)\\Avg. Disk Queue Length",
      ]
    }
  }

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id
      name                  = azurerm_log_analytics_workspace.this_workspace.name
    }
  }

  data_flow {
    streams      = ["Microsoft-Event", "Microsoft-Perf"]
    destinations = [azurerm_log_analytics_workspace.this_workspace.name]
  }
}

# associate to a Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "this_rule_association" {

  name                    = "${azurerm_monitor_data_collection_rule.test.name}-association"
  target_resource_id      = module.testvm.virtual_machine.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.test.id
  description             = "test data collection rule association"
}


output "vm" {
  value     = module.testvm.virtual_machine
  sensitive = true
}
