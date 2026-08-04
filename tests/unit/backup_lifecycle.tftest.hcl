mock_provider "azapi" {
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

run "missing_backup_item_is_created" {
  command = apply

  assert {
    condition     = data.azapi_resource.backup_item["main"].ignore_not_found
    error_message = "The backup item lookup must tolerate a missing protected item during initial creation."
  }
  assert {
    condition     = azapi_resource_action.backup_ensure_active["main"].method == "PUT"
    error_message = "A missing backup item must be created with a PUT request."
  }
  assert {
    condition     = azapi_resource_action.backup_ensure_active["main"].body.properties.policyId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
    error_message = "The create request must contain the configured backup policy."
  }
  assert {
    condition     = azapi_update_resource.backup_protection["main"].body.properties.sourceResourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-backup"
    error_message = "The managed backup configuration must reference the virtual machine resource ID."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy["main"].method == "DELETE"
    error_message = "The default destroy behavior must continue to delete the protected item."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy["main"].resource_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;rg-test;vm-backup/protectedItems/VM;iaasvmcontainerv2;rg-test;vm-backup"
    error_message = "The protected item resource ID must support a vault in a different subscription from the VM."
  }
}

run "soft_deleted_backup_item_is_rehydrated" {
  command = apply

  override_data {
    target = data.azapi_resource.backup_item["main"]
    values = {
      exists = true
      output = {
        properties = {
          isScheduledForDeferredDelete = true
        }
      }
    }
  }

  assert {
    condition     = azapi_resource_action.backup_ensure_active["main"].body.properties.isRehydrate
    error_message = "A soft-deleted protected item must be rehydrated before its backup configuration is applied."
  }
  assert {
    condition     = azapi_resource_action.backup_ensure_active["main"].body.properties.protectedItemType == "Microsoft.Compute/virtualMachines"
    error_message = "The rehydrate request must include the protectedItemType discriminator required by the Backup API."
  }
  assert {
    condition     = azapi_update_resource.backup_protection["main"].body.properties.policyId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
    error_message = "The full backup configuration must be managed after rehydrating a soft-deleted item."
  }
}

run "active_backup_item_is_adopted" {
  command = apply

  override_data {
    target = data.azapi_resource.backup_item["main"]
    values = {
      exists = true
      output = {
        properties = {
          isScheduledForDeferredDelete = false
        }
      }
    }
  }

  assert {
    condition     = azapi_resource_action.backup_ensure_active["main"].body.properties.policyId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
    error_message = "An existing active or ProtectionStopped item must be adopted with the full backup configuration rather than rehydrated."
  }
}

run "backup_data_can_be_retained_on_destroy" {
  command = apply

  variables {
    azure_backup_configurations = {
      main = {
        recovery_vault_resource_id    = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test"
        backup_policy_resource_id     = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
        retain_backup_data_on_destroy = true
      }
    }
  }

  assert {
    condition     = azapi_resource_action.backup_destroy["main"].method == "PUT"
    error_message = "Retaining backup data must use a PUT instead of deleting the protected item."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy["main"].body.properties.protectionState == "ProtectionStopped"
    error_message = "Retaining backup data must stop protection while preserving recovery points."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy["main"].body.properties.sourceResourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-backup"
    error_message = "The stop-protection request must identify the protected virtual machine."
  }
}

run "backup_resources_are_not_created_without_configuration" {
  command = apply

  variables {
    azure_backup_configurations = {}
  }

  assert {
    condition     = length(azapi_resource_action.backup_ensure_active) == 0
    error_message = "Backup lifecycle resources must not be created when no backup configuration is supplied."
  }
  assert {
    condition     = length(azapi_update_resource.backup_protection) == 0
    error_message = "Backup drift management must not be created when no backup configuration is supplied."
  }
  assert {
    condition     = length(azapi_resource_action.backup_destroy) == 0
    error_message = "Backup destroy actions must not be created when no backup configuration is supplied."
  }
}
