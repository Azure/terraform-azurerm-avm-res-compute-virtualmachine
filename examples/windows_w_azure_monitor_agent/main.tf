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

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

#create a keyvault for storing the credential with RBAC for the deployment user
module "avm_res_keyvault_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "=0.10.0"

  location                    = azurerm_resource_group.this_rg.location
  name                        = "${module.naming.key_vault.name_unique}-win-ama"
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
  }
  tags = local.tags
  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }
}

resource "azurerm_log_analytics_workspace" "this_workspace" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
  tags                = local.tags
}

data "azurerm_key_vault" "this" {
  name                = basename(module.avm_res_keyvault_vault.resource_id)
  resource_group_name = azurerm_resource_group.this_rg.name
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

      diagnostic_settings = {
        nic_diags = {
          name                  = module.naming.monitor_diagnostic_setting.name_unique
          workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }
  resource_group_name = azurerm_resource_group.this_rg.name
  zone                = random_integer.zone_index.result
  account_credentials = {
    key_vault_configuration = {
      resource_id = module.avm_res_keyvault_vault.resource_id
      secret_configuration = {
        name                           = "example-custom-secret-name"
        expiration_date_length_in_days = 30
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
  enable_telemetry           = var.enable_telemetry
  encryption_at_host_enabled = false
  extensions = {
    azure_monitor_agent = {
      name                       = "AzureMonitorWindowsAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorWindowsAgent"
      type_handler_version       = "1.2"
      auto_upgrade_minor_version = true
      automatic_upgrade_enabled  = true
      settings                   = null
    }
    azure_disk_encryption = {
      name                       = "AzureDiskEncryption"
      publisher                  = "Microsoft.Azure.Security"
      type                       = "AzureDiskEncryption"
      type_handler_version       = "2.2"
      auto_upgrade_minor_version = true
      settings                   = <<SETTINGS
          {
              "EncryptionOperation": "EnableEncryption",
              "KeyVaultURL": "${data.azurerm_key_vault.this.vault_uri}",
              "KeyVaultResourceId": "${module.avm_res_keyvault_vault.resource_id}",
              "KeyEncryptionAlgorithm": "RSA-OAEP",
              "VolumeType": "All"
          }
      SETTINGS
    }
  }
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }
  os_type  = "Windows"
  sku_size = module.vm_sku.sku
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
  tags = {
    scenario = "windows_w_azure_monitor_agent"
  }

  depends_on = [
    module.avm_res_keyvault_vault
  ]
}

resource "azurerm_monitor_data_collection_rule" "test" {
  location            = azurerm_resource_group.this_rg.location
  name                = "${module.testvm.virtual_machine.name}-dcr"
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags

  data_flow {
    destinations = [azurerm_log_analytics_workspace.this_workspace.name]
    streams      = ["Microsoft-Event", "Microsoft-Perf"]
  }
  destinations {
    log_analytics {
      name                  = azurerm_log_analytics_workspace.this_workspace.name
      workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id
    }
  }
  data_sources {
    performance_counter {
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
      name                          = "exampleCounters"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]
    }
    windows_event_log {
      name    = "eventLogsDataSource"
      streams = ["Microsoft-Event"]
      x_path_queries = ["Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        "Security!*[System[(band(Keywords,4503599627370496))]]",
      "System!*[System[(Level=1 or Level=2 or Level=3)]]"]
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "this_rule_association" {
  target_resource_id      = module.testvm.virtual_machine.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.test.id
  description             = "test data collection rule association"
  name                    = "${azurerm_monitor_data_collection_rule.test.name}-association"
}
