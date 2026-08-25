mock_provider "azapi" {
  # The virtual machine is still an azurerm resource and parses each network_interface_ids entry as
  # an ARM ID, so the mocked interface must carry a well-formed one rather than the generated
  # placeholder.
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }
}
mock_provider "azurerm" {
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }

  mock_resource "azurerm_windows_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-backup"
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-backup-osdisk"
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "avmUnitTest123!"
    }
  }
}
mock_provider "tls" {}

# The blanket azapi_resource mock gives every azapi resource the same id, which the still-azurerm
# resources reject when they parse it as a virtual machine ID. The virtual machine also has to
# expose an output, because the OS disk lock and network access updater read its managed disk id
# back off the created machine.
override_resource {
  target = azapi_resource.this_linux_virtual_machine
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
    output = {
      identity = {
        principalId = "11111111-1111-1111-1111-111111111111"
        tenantId    = "22222222-2222-2222-2222-222222222222"
      }
      properties = {
        vmId = "33333333-3333-3333-3333-333333333333"
        storageProfile = {
          osDisk = {
            managedDisk = {
              id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-test-osdisk"
            }
          }
        }
      }
    }
  }
}

variables {
  location            = "eastus"
  name                = "vm-backup"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Windows"
  azure_backup_configurations = {
    main = {
      recovery_vault_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test"
      backup_policy_resource_id  = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
    }
  }
  network_interfaces = {
    network_interface_1 = {
      name = "nic-test"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "nic-test-ipconfig1"
          private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        }
      }
    }
  }
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

run "backup_configuration_is_delegated_to_submodule" {
  command = apply

  assert {
    condition     = length(module.backup) == 1
    error_message = "A backup configuration must instantiate exactly one backup submodule instance."
  }
  assert {
    condition     = module.backup["main"].resource_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;rg-test;vm-backup/protectedItems/VM;iaasvmcontainerv2;rg-test;vm-backup"
    error_message = "The root module must compose the protected item resource ID from the VM resource group and name and the recovery services vault, supporting a vault in a different subscription."
  }
}

run "backup_submodule_is_not_created_without_configuration" {
  command = apply

  variables {
    azure_backup_configurations = {}
  }

  assert {
    condition     = length(module.backup) == 0
    error_message = "The backup submodule must not be instantiated when no backup configuration is supplied."
  }
}
