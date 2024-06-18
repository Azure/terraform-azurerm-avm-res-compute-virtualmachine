module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = "~> 0.6"
}

locals {
  tags = {
    scenario = "windows_w_gallery_application"
  }
  test_regions = ["centralus", "eastasia", "eastus2", "westus3"]
}

resource "random_integer" "region_index" {
  max = length(local.test_regions) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.test_regions[random_integer.region_index.result]].zones)
  min = 1
}

module "get_valid_sku_for_deployment_region" {
  source = "../../modules/sku_selector"

  deployment_region = local.test_regions[random_integer.region_index.result]
}

resource "azurerm_resource_group" "this_rg" {
  location = local.test_regions[random_integer.region_index.result]
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
  version                     = "~> 0.5.0"
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
      #principal_type             = "ServicePrincipal"
    }
    deployment_user_keys = { #give the deployment user access to keys
      role_definition_id_or_name = "Key Vault Crypto Officer"
      principal_id               = data.azurerm_client_config.current.object_id
      #principal_type             = "ServicePrincipal"
    }
    user_managed_identity_keys = { #give the user assigned managed identity for the disk encryption set access to keys
      role_definition_id_or_name = "Key Vault Crypto Officer"
      principal_id               = azurerm_user_assigned_identity.test.principal_id
      principal_type             = "ServicePrincipal"
    }
  }

  wait_for_rbac_before_key_operations = {
    create = "60s"
  }

  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }

  tags = local.tags

  keys = {
    des_key = {
      name     = "des-disk-key"
      key_type = "RSA"
      key_size = 2048

      key_opts = [
        "decrypt",
        "encrypt",
        "sign",
        "unwrapKey",
        "verify",
        "wrapKey",
      ]

      rotation_policy = {
        automatic = {
          time_before_expiry = "P30D"
        }

        expire_after         = "P90D"
        notify_before_expiry = "P29D"
      }
    }
  }
}


resource "azurerm_recovery_services_vault" "test_vault" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.recovery_services_vault.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  sku                 = "Standard"
  soft_delete_enabled = false
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

module "testnsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.1.1"

  enable_telemetry    = var.enable_telemetry
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  name                = module.naming.network_security_group.name_unique
  nsgrules = { #allow all just to show the association. Add your custom rules here
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

resource "azurerm_user_assigned_identity" "test" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

resource "azurerm_disk_encryption_set" "this" {
  key_vault_key_id          = module.avm_res_keyvault_vault.resource_keys.des_key.versionless_id
  location                  = azurerm_resource_group.this_rg.location
  name                      = module.naming.disk_encryption_set.name_unique
  resource_group_name       = azurerm_resource_group.this_rg.name
  auto_key_rotation_enabled = true
  tags                      = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.test.id]
  }
}

module "testvm" {
  source = "../../"
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.14.0"

  enable_telemetry                                       = var.enable_telemetry
  location                                               = azurerm_resource_group.this_rg.location
  resource_group_name                                    = azurerm_resource_group.this_rg.name
  virtualmachine_os_type                                 = "Windows"
  name                                                   = module.naming.virtual_machine.name_unique
  admin_credential_key_vault_resource_id                 = module.avm_res_keyvault_vault.resource.id
  virtualmachine_sku_size                                = module.get_valid_sku_for_deployment_region.sku
  encryption_at_host_enabled                             = true
  zone                                                   = random_integer.zone_index.result
  patch_assessment_mode                                  = "AutomaticByPlatform"
  patch_mode                                             = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  boot_diagnostics                                       = true

  managed_identities = {
    system_assigned = true
  }

  os_disk = {
    caching                = "ReadWrite"
    storage_account_type   = "Premium_ZRS"
    disk_encryption_set_id = azurerm_disk_encryption_set.this.id
  }

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  network_interfaces = {
    network_interface_1 = {
      name                           = module.naming.network_interface.name_unique
      accelerated_networking_enabled = true
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = azurerm_subnet.this_subnet_1.id
        }
      }
      network_security_groups = {
        nsg_1 = {
          network_security_group_resource_id = module.testnsg.nsg_resource.id
        }
      }
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

resource "azurerm_log_analytics_workspace" "this_workspace" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
  tags                = local.tags
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

locals {
  extension_setting_linux   = jsonencode(local.extension_settings_object_linux)
  extension_setting_windows = jsonencode(local.extension_settings_object_windows)
  extension_settings_object_linux = {
    enableFiles     = true
    enableSoftware  = true
    enableRegistry  = false
    enableServices  = true
    enableInventory = true
    fileSettings = {
      fileCollectionFrequency = 900
      fileInfo = [
        {
          name                  = "ChangeTrackingLinuxPath_default"
          enabled               = true
          destinationPath       = "/etc/.*.conf"
          useSudo               = true
          recurse               = true
          maxContentsReturnable = 5000000
          pathType              = "File"
          type                  = "File"
          links                 = "Follow"
          maxOutputSize         = 500000
          groupTag              = "Recommended"
        }
      ]
    }
    softwareSettings = {
      softwareCollectionFrequency = 300
    }
    inventorySettings = {
      inventoryCollectionFrequency = 36000
    }
    serviceSettings = {
      serviceCollectionFrequency = 300
    }
  }
  extension_settings_object_windows = {
    enableFiles     = true
    enableSoftware  = true
    enableRegistry  = true
    enableServices  = true
    enableInventory = true
    registrySettings = {
      registryCollectionFrequency = 3000
      registryInfo = [
        {
          name        = "Registry_1"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Group Policy\\Scripts\\Startup"
          valueName   = ""
        },
        {
          name        = "Registry_2"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Group Policy\\Scripts\\Shutdown"
          valueName   = ""
        },
        {
          name        = "Registry_3"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Run"
          valueName   = ""
        },
        {
          name        = "Registry_4"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Active Setup\\Installed Components"
          valueName   = ""
        },
        {
          name        = "Registry_5"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Classes\\Directory\\ShellEx\\ContextMenuHandlers"
          valueName   = ""
        },
        {
          name        = "Registry_5"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Classes\\Directory\\ShellEx\\ContextMenuHandlers"
          valueName   = ""
        },
        {
          name        = "Registry_6"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Classes\\Directory\\Background\\ShellEx\\ContextMenuHandlers"
          valueName   = ""
        },
        {
          name        = "Registry_7"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Classes\\Directory\\Shellex\\CopyHookHandlers"
          valueName   = ""
        },
        {
          name        = "Registry_8"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ShellIconOverlayIdentifiers"
          valueName   = ""
        },
        {
          name        = "Registry_9"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ShellIconOverlayIdentifiers"
          valueName   = ""
        },
        {
          name        = "Registry_10"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Browser Helper Objects"
          valueName   = ""
        },
        {
          name        = "Registry_11"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Browser Helper Objects"
          valueName   = ""
        },
        {
          name        = "Registry_12"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\Extensions"
          valueName   = ""
        },
        {
          name        = "Registry_13"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Internet Explorer\\Extensions"
          valueName   = ""
        },
        {
          name        = "Registry_14"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Drivers32"
          valueName   = ""
        },
        {
          name        = "Registry_15"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\Software\\Wow6432Node\\Microsoft\\Windows NT\\CurrentVersion\\Drivers32"
          valueName   = ""
        },
        {
          name        = "Registry_16"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\KnownDlls"
          valueName   = ""
        },
        {
          name        = "Registry_17"
          groupTag    = "Recommended"
          enabled     = false
          recurse     = true
          description = ""
          keyName     = "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\\Notify"
          valueName   = ""
        }
      ]
    }
    fileSettings = {
      fileCollectionFrequency = 2700
    }
    softwareSettings = {
      softwareCollectionFrequency = 1800
    }
    inventorySettings = {
      inventoryCollectionFrequency = 36000
    }
    serviceSettings = {
      serviceCollectionFrequency = 1800
    }
  }
}

resource "azurerm_monitor_data_collection_rule" "change_tracking" {
  location            = azurerm_resource_group.this_rg.location
  name                = "${module.testvm.virtual_machine.name}-dcr-change-tracking"
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags

  data_flow {
    destinations = [azurerm_log_analytics_workspace.this_workspace.name]
    streams = ["Microsoft-ConfigurationChange",
      "Microsoft-ConfigurationChangeV2",
    "Microsoft-ConfigurationData"]
  }
  destinations {
    log_analytics {
      name                  = azurerm_log_analytics_workspace.this_workspace.name
      workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id
    }
  }
  data_sources {
    extension {
      extension_name = "ChangeTracking-Windows"
      name           = "CTDataSource-Windows"
      streams = [
        "Microsoft-ConfigurationChange",
        "Microsoft-ConfigurationChangeV2",
        "Microsoft-ConfigurationData"
      ]
      extension_json = local.extension_setting_windows
    }
    extension {
      extension_name = "ChangeTracking-Linux"
      name           = "CTDataSource-Linux"
      streams = [
        "Microsoft-ConfigurationChange",
        "Microsoft-ConfigurationChangeV2",
        "Microsoft-ConfigurationData"
      ]
      extension_json = local.extension_setting_linux
    }
  }

  depends_on = [azurerm_log_analytics_solution.change_tracking]
}


resource "azurerm_monitor_data_collection_rule_association" "this_rule_association" {
  target_resource_id      = module.testvm.virtual_machine.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.change_tracking.id
  description             = "Change Tracking data collection rule association"
  name                    = "${azurerm_monitor_data_collection_rule.change_tracking.name}-association"
}

resource "azurerm_log_analytics_solution" "change_tracking" {
  location              = azurerm_resource_group.this_rg.location
  resource_group_name   = azurerm_resource_group.this_rg.name
  solution_name         = "ChangeTracking"
  workspace_name        = azurerm_log_analytics_workspace.this_workspace.name
  workspace_resource_id = azurerm_log_analytics_workspace.this_workspace.id

  plan {
    product   = "OMSGallery/ChangeTracking"
    publisher = "Microsoft"
  }
}
