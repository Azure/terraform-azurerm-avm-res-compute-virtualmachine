mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }
}

variables {
  enable_telemetry           = false
  resource_group_name        = "rg-test"
  virtual_machine_name       = "vm-backup"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-backup"
  recovery_vault_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test"
  backup_policy_resource_id  = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
}

run "missing_backup_item_is_created" {
  command = apply

  assert {
    condition     = data.azapi_resource.backup_item.ignore_not_found
    error_message = "The backup item lookup must tolerate a missing protected item during initial creation."
  }
  assert {
    condition     = azapi_resource_action.backup_ensure_active.method == "PUT"
    error_message = "A missing backup item must be created with a PUT request."
  }
  assert {
    condition     = azapi_resource_action.backup_ensure_active.body.properties.policyId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
    error_message = "The create request must contain the configured backup policy."
  }
  assert {
    condition     = azapi_update_resource.backup_protection.body.properties.sourceResourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-backup"
    error_message = "The managed backup configuration must reference the virtual machine resource ID."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy.method == "DELETE"
    error_message = "The default destroy behavior must continue to delete the protected item."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy.resource_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;rg-test;vm-backup/protectedItems/VM;iaasvmcontainerv2;rg-test;vm-backup"
    error_message = "The protected item resource ID must support a vault in a different subscription from the VM."
  }
}

run "soft_deleted_backup_item_is_rehydrated" {
  command = apply

  override_data {
    target = data.azapi_resource.backup_item
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
    condition     = azapi_resource_action.backup_ensure_active.body.properties.isRehydrate
    error_message = "A soft-deleted protected item must be rehydrated before its backup configuration is applied."
  }
  assert {
    condition     = azapi_resource_action.backup_ensure_active.body.properties.protectedItemType == "Microsoft.Compute/virtualMachines"
    error_message = "The rehydrate request must include the protectedItemType discriminator required by the Backup API."
  }
  assert {
    condition     = azapi_update_resource.backup_protection.body.properties.policyId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
    error_message = "The full backup configuration must be managed after rehydrating a soft-deleted item."
  }
}

run "active_backup_item_is_adopted" {
  command = apply

  override_data {
    target = data.azapi_resource.backup_item
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
    condition     = azapi_resource_action.backup_ensure_active.body.properties.policyId == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-backup/providers/Microsoft.RecoveryServices/vaults/rsv-test/backupPolicies/policy-test"
    error_message = "An existing active or ProtectionStopped item must be adopted with the full backup configuration rather than rehydrated."
  }
}

run "backup_data_can_be_retained_on_destroy" {
  command = apply

  variables {
    retain_backup_data_on_destroy = true
  }

  assert {
    condition     = azapi_resource_action.backup_destroy.method == "PUT"
    error_message = "Retaining backup data must use a PUT instead of deleting the protected item."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy.body.properties.protectionState == "ProtectionStopped"
    error_message = "Retaining backup data must stop protection while preserving recovery points."
  }
  assert {
    condition     = azapi_resource_action.backup_destroy.body.properties.sourceResourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-backup"
    error_message = "The stop-protection request must identify the protected virtual machine."
  }
}

run "excluded_disk_luns_are_sent_as_exclusion_list" {
  command = apply

  variables {
    exclude_disk_luns = [0, 1]
  }

  assert {
    condition     = azapi_update_resource.backup_protection.body.properties.extendedProperties.diskExclusionProperties.isInclusionList == false
    error_message = "exclude_disk_luns must be sent as an exclusion list."
  }
  assert {
    condition     = azapi_update_resource.backup_protection.body.properties.extendedProperties.diskExclusionProperties.diskLunList == tolist([0, 1])
    error_message = "The excluded disk LUNs must be forwarded to the protected item configuration."
  }
}
