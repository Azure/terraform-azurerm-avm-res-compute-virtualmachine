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
  backup_item_is_soft_deleted = {
    for key, value in var.azure_backup_configurations : key => data.azapi_resource.backup_item[key].exists && try(
      data.azapi_resource.backup_item[key].output.properties.isScheduledForDeferredDelete == true,
      false
    )
  }
  backup_item_resource_ids = {
    for key, value in var.azure_backup_configurations : key => "${value.recovery_vault_resource_id}/backupFabrics/Azure/protectionContainers/iaasvmcontainer;iaasvmcontainerv2;${var.resource_group_name};${var.name}/protectedItems/VM;iaasvmcontainerv2;${var.resource_group_name};${var.name}"
  }
  backup_protected_item_resource_type = "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-10-01"
}

data "azapi_resource" "backup_item" {
  for_each = var.azure_backup_configurations

  resource_id            = local.backup_item_resource_ids[each.key]
  type                   = local.backup_protected_item_resource_type
  headers                = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_not_found       = true
  response_export_values = ["properties.isScheduledForDeferredDelete"]
}

# A protected item can be absent, active, stopped, or soft-deleted. A PUT creates or resumes the
# first three states; a soft-deleted item must be rehydrated before its configuration can be updated.
resource "azapi_resource_action" "backup_ensure_active" {
  for_each = var.azure_backup_configurations

  method      = "PUT"
  resource_id = local.backup_item_resource_ids[each.key]
  type        = local.backup_protected_item_resource_type
  body = jsondecode(local.backup_item_is_soft_deleted[each.key] ? jsonencode({
    properties = {
      isRehydrate       = true
      protectedItemType = "Microsoft.Compute/virtualMachines"
    }
    }) : jsonencode({
    properties = local.backup_body_properties[each.key]
  }))
  headers                = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  locks                  = [local.backup_item_resource_ids[each.key]]
  response_export_values = []
  when                   = "apply"

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}

# Manage the declared backup properties after the create/resume/rehydrate operation. Unlike
# azapi_resource, deleting azapi_update_resource performs no remote operation; teardown behavior is
# handled explicitly by backup_destroy below.
resource "azapi_update_resource" "backup_protection" {
  for_each = var.azure_backup_configurations

  resource_id = local.backup_item_resource_ids[each.key]
  type        = local.backup_protected_item_resource_type
  body = {
    properties = local.backup_body_properties[each.key]
  }
  ignore_casing          = true
  locks                  = [local.backup_item_resource_ids[each.key]]
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = []
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  depends_on = [azapi_resource_action.backup_ensure_active]
}

# The Backup API uses PUT ProtectionStopped to retain recovery points and DELETE to remove them.
# Modeling the destroy request separately avoids azapi_resource's unconditional DELETE behavior.
resource "azapi_resource_action" "backup_destroy" {
  for_each = var.azure_backup_configurations

  method      = each.value.retain_backup_data_on_destroy ? "PUT" : "DELETE"
  resource_id = local.backup_item_resource_ids[each.key]
  type        = local.backup_protected_item_resource_type
  body = each.value.retain_backup_data_on_destroy ? {
    properties = {
      protectedItemType = "Microsoft.Compute/virtualMachines"
      protectionState   = "ProtectionStopped"
      sourceResourceId  = local.virtualmachine_resource_id
    }
  } : null
  headers                = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_not_found       = true
  locks                  = [local.backup_item_resource_ids[each.key]]
  response_export_values = []
  when                   = "destroy"

  depends_on = [azapi_update_resource.backup_protection]
}

# Previous module versions used both resource types below. Forget their state entries without
# issuing a remote delete; the lifecycle resources above inspect and adopt the existing item.
removed {
  from = azapi_resource.this_backup_intent

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_backup_protected_vm.this

  lifecycle {
    destroy = false
  }
}
