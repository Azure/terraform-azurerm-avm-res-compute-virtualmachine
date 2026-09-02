module "backup" {
  source   = "./modules/backup"
  for_each = var.azure_backup_configurations

  recovery_vault_resource_id    = each.value.recovery_vault_resource_id
  resource_group_name           = var.resource_group_name
  virtual_machine_name          = var.name
  virtualmachine_resource_id    = local.virtualmachine_resource_id
  backup_policy_resource_id     = each.value.backup_policy_resource_id
  enable_telemetry              = var.enable_telemetry
  exclude_disk_luns             = each.value.exclude_disk_luns
  ignore_body_changes           = var.ignore_body_changes.recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems
  include_disk_luns             = each.value.include_disk_luns
  resource_types                = var.resource_types.recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems
  retain_backup_data_on_destroy = each.value.retain_backup_data_on_destroy
  retry                         = var.retry
  timeouts                      = var.timeouts

  depends_on = [
    azapi_resource.this_linux_virtual_machine,
    azapi_resource.this_windows_virtual_machine
  ]
}

# The backup protected-item lifecycle previously lived in the root module (keyed by the
# azure_backup_configurations map) and now lives in ./modules/backup. The map keys are user-defined,
# so static keyed `moved` blocks cannot be generated. Instead, forget the previous root-level state
# entries without issuing any remote operation. The backup submodule then inspects and adopts the
# existing protected item, exactly as it does when migrating from the historical addresses below.
# In particular this prevents the previous `azapi_resource_action.backup_destroy` (when = destroy)
# from firing a DELETE against the protected item during the upgrade.
removed {
  from = azapi_resource_action.backup_ensure_active

  lifecycle {
    destroy = false
  }
}

removed {
  from = azapi_update_resource.backup_protection

  lifecycle {
    destroy = false
  }
}

removed {
  from = azapi_resource_action.backup_destroy

  lifecycle {
    destroy = false
  }
}

# Previous module versions used both resource types below. Forget their state entries without
# issuing a remote delete; the backup submodule inspects and adopts the existing item.
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
