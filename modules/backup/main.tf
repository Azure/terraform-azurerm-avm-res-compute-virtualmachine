locals {
  # The protection container and protected item names are derived from the virtual machine's
  # resource group and name. The recovery services vault may live in another subscription.
  backup_container_name               = "iaasvmcontainerv2;${var.resource_group_name};${var.virtual_machine_name}"
  backup_protected_item_resource_type = var.resource_types.recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems
  backup_item_resource_id             = "${var.recovery_vault_resource_id}/backupFabrics/Azure/protectionContainers/iaasvmcontainer;${local.backup_container_name}/protectedItems/VM;${local.backup_container_name}"
  backup_body_extended_properties = try(length(var.exclude_disk_luns) > 0, false) ? {
    extendedProperties = {
      diskExclusionProperties = {
        diskLunList     = var.exclude_disk_luns
        isInclusionList = false
      }
    }
    } : try(length(var.include_disk_luns) > 0, false) ? {
    extendedProperties = {
      diskExclusionProperties = {
        diskLunList     = var.include_disk_luns
        isInclusionList = true
      }
    }
  } : {}
  base_backup_body_properties = {
    protectedItemType = "Microsoft.Compute/virtualMachines"
    sourceResourceId  = var.virtualmachine_resource_id
    policyId          = var.backup_policy_resource_id
    containerName     = local.backup_container_name
    policyName        = basename(var.backup_policy_resource_id)
  }
  backup_body_properties      = merge(local.base_backup_body_properties, local.backup_body_extended_properties)
  backup_item_is_soft_deleted = data.azapi_resource.backup_item.exists && try(data.azapi_resource.backup_item.output.properties.isScheduledForDeferredDelete == true, false)
}

data "azapi_resource" "backup_item" {
  resource_id            = local.backup_item_resource_id
  type                   = local.backup_protected_item_resource_type
  headers                = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_not_found       = true
  response_export_values = ["properties.isScheduledForDeferredDelete"]
}

# A protected item can be absent, active, stopped, or soft-deleted. A PUT creates or resumes the
# first three states; a soft-deleted item must be rehydrated before its configuration can be updated.
resource "azapi_resource_action" "backup_ensure_active" {
  method      = "PUT"
  resource_id = local.backup_item_resource_id
  type        = local.backup_protected_item_resource_type
  body = jsondecode(local.backup_item_is_soft_deleted ? jsonencode({
    properties = {
      isRehydrate       = true
      protectedItemType = "Microsoft.Compute/virtualMachines"
    }
    }) : jsonencode({
    properties = local.backup_body_properties
  }))
  headers                = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  locks                  = [local.backup_item_resource_id]
  response_export_values = []
  when                   = "apply"
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# Manage the declared backup properties after the create/resume/rehydrate operation. Unlike
# azapi_resource, deleting azapi_update_resource performs no remote operation; teardown behavior is
# handled explicitly by backup_destroy below.
resource "azapi_update_resource" "backup_protection" {
  resource_id = local.backup_item_resource_id
  type        = local.backup_protected_item_resource_type
  body = {
    properties = local.backup_body_properties
  }
  ignore_casing          = true
  locks                  = [local.backup_item_resource_id]
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = []
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  depends_on = [azapi_resource_action.backup_ensure_active]
  retry      = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# The Backup API uses PUT ProtectionStopped to retain recovery points and DELETE to remove them.
# Modeling the destroy request separately avoids azapi_resource's unconditional DELETE behavior.
resource "azapi_resource_action" "backup_destroy" {
  method      = var.retain_backup_data_on_destroy ? "PUT" : "DELETE"
  resource_id = local.backup_item_resource_id
  type        = local.backup_protected_item_resource_type
  body = var.retain_backup_data_on_destroy ? {
    properties = {
      protectedItemType = "Microsoft.Compute/virtualMachines"
      protectionState   = "ProtectionStopped"
      sourceResourceId  = var.virtualmachine_resource_id
    }
  } : null
  headers                = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_not_found       = true
  locks                  = [local.backup_item_resource_id]
  response_export_values = []
  when                   = "destroy"

  depends_on = [azapi_update_resource.backup_protection]
  retry      = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}
