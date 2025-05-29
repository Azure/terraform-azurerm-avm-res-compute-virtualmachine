/* Leaving this in case we have to revert the azAPI changes.
resource "azurerm_backup_protected_vm" "this" {
  for_each = var.azure_backup_configurations

  recovery_vault_name = each.value.recovery_vault_name
  resource_group_name = coalesce(each.value.resource_group_name, var.resource_group_name)
  backup_policy_id    = each.value.backup_policy_resource_id
  exclude_disk_luns   = each.value.exclude_disk_luns
  include_disk_luns   = each.value.include_disk_luns
  #protection_state    = each.value.protection_state
  source_vm_id        = local.virtualmachine_resource_id

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}
*/
locals {
  backup_body_extended_properties = { for key, value in var.azure_backup_configurations : key => try(length(value.exclude_disk_luns) > 0, false) ? {
    extendedProperties = {
      diskExclusionProperties = {
        diskLunList     = value.exclude_disk_luns
        isInclusionList = false
      }
    }
    } : try(length(value.include_disk_luns) > 0, false) ? {
    extendedProperties = {
      diskExclusionProperties = {
        diskLunList     = value.include_disk_luns
        isInclusionList = true
      }
    }
    } : {}
  }
  backup_body_properties = { for key, value in var.azure_backup_configurations : key => merge(local.base_backup_body_properties[key], local.backup_body_extended_properties[key]) }
  base_backup_body_properties = { for key, value in var.azure_backup_configurations : key => {
    protectedItemType = "Microsoft.Compute/virtualMachines"
    sourceResourceId  = local.virtualmachine_resource_id
    policyId          = value.backup_policy_resource_id
    containerName     = "iaasvmcontainerv2;${var.resource_group_name};${var.name}"
    policyName        = basename(value.backup_policy_resource_id)
    }
  }
  rsv_resource_group = { for key, value in var.azure_backup_configurations : key => try(split("/", split("resourceGroups/", value.recovery_vault_resource_id)[1])[0], null) }
}

resource "azapi_resource" "this_backup_intent" {
  for_each = var.azure_backup_configurations

  name      = "VM;iaasvmcontainerv2;${coalesce(each.value.resource_group_name, local.rsv_resource_group[each.key], var.resource_group_name)};${var.name}"
  parent_id = "${each.value.recovery_vault_resource_id}/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;${var.resource_group_name};${var.name}"
  type      = "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-10-01"
  body = {
    properties = local.backup_body_properties[each.key]
  }
  response_export_values = ["*"]
}


moved {
  from = azurerm_backup_protected_vm.this
  to   = azapi_resource.this_backup_intent
}

