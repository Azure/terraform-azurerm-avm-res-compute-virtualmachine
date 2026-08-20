locals {
  # Every role assignment this module manages, merged into one map so the interfaces utility
  # performs a single role-definition lookup rather than one per owner. Keys are prefixed by owner
  # to keep them unique; each azapi_resource below still uses its own original for_each keys, so
  # the `moved` blocks map one-to-one and consumer state is preserved.
  interface_role_assignments = merge(
    { for k, v in var.role_assignments : "vm-${k}" => {
      role_definition_id_or_name             = v.role_definition_id_or_name
      principal_id                           = v.principal_id
      description                            = v.description
      skip_service_principal_aad_check       = v.skip_service_principal_aad_check
      condition                              = v.condition
      condition_version                      = v.condition_version
      delegated_managed_identity_resource_id = v.delegated_managed_identity_resource_id
      principal_type                         = v.principal_type
    } },
    { for k, v in var.role_assignments_system_managed_identity : "smi-${k}" => {
      role_definition_id_or_name             = v.role_definition_id_or_name
      principal_id                           = local.system_managed_identity_id
      description                            = v.description
      skip_service_principal_aad_check       = v.skip_service_principal_aad_check
      condition                              = v.condition
      condition_version                      = v.condition_version
      delegated_managed_identity_resource_id = v.delegated_managed_identity_resource_id
      principal_type                         = v.principal_type
    } },
    { for k, v in local.nics_role_assignments : "nic-${k}" => {
      role_definition_id_or_name             = v.role_assignment.role_definition_id_or_name
      principal_id                           = v.role_assignment.principal_id
      description                            = v.role_assignment.description
      skip_service_principal_aad_check       = v.role_assignment.skip_service_principal_aad_check
      condition                              = v.role_assignment.condition
      condition_version                      = v.role_assignment.condition_version
      delegated_managed_identity_resource_id = v.role_assignment.delegated_managed_identity_resource_id
      principal_type                         = v.role_assignment.principal_type
    } },
    { for k, v in local.disks_role_assignments : "disk-${k}" => {
      role_definition_id_or_name             = v.role_assignment.role_definition_id_or_name
      principal_id                           = v.role_assignment.principal_id
      description                            = v.role_assignment.description
      skip_service_principal_aad_check       = v.role_assignment.skip_service_principal_aad_check
      condition                              = v.role_assignment.condition
      condition_version                      = v.role_assignment.condition_version
      delegated_managed_identity_resource_id = v.role_assignment.delegated_managed_identity_resource_id
      principal_type                         = v.role_assignment.principal_type
    } },
  )
  # Diagnostic settings are assembled here rather than through the interfaces utility. That module's
  # log_analytics_destination_type defaults to "Dedicated" and rejects null, while this module has
  # always allowed null (meaning "let Azure decide"). Routing through it would silently change the
  # destination type for any consumer who left the value unset.
  interface_diagnostic_settings_vm = {
    for k, v in var.diagnostic_settings : k => {
      properties = {
        eventHubAuthorizationRuleId = v.event_hub_authorization_rule_resource_id
        eventHubName                = v.event_hub_name
        logAnalyticsDestinationType = v.log_analytics_destination_type == "Dedicated" ? null : v.log_analytics_destination_type
        logs = concat(
          [for c in v.log_categories : { category = c, categoryGroup = null, enabled = true }],
          [for g in v.log_groups : { category = null, categoryGroup = g, enabled = true }],
        )
        marketplacePartnerId = v.marketplace_partner_resource_id
        metrics              = [for m in v.metric_categories : { category = m, enabled = true }]
        storageAccountId     = v.storage_account_resource_id
        workspaceId          = v.workspace_resource_id
      }
    }
  }
  interface_diagnostic_settings_nic = {
    for k, v in local.nics_diag_settings : k => {
      properties = {
        eventHubAuthorizationRuleId = v.diagnostic_setting.event_hub_authorization_rule_resource_id
        eventHubName                = v.diagnostic_setting.event_hub_name
        logAnalyticsDestinationType = v.diagnostic_setting.log_analytics_destination_type
        logs = concat(
          [for c in v.diagnostic_setting.log_categories : { category = c, categoryGroup = null, enabled = true }],
          [for g in v.diagnostic_setting.log_groups : { category = null, categoryGroup = g, enabled = true }],
        )
        marketplacePartnerId = v.diagnostic_setting.marketplace_partner_resource_id
        metrics              = [for m in v.diagnostic_setting.metric_categories : { category = m, enabled = true }]
        storageAccountId     = v.diagnostic_setting.storage_account_resource_id
        workspaceId          = v.diagnostic_setting.workspace_resource_id
      }
    }
  }
  # A lock body is trivial, but the notes wording must match what the module already produces so the
  # migration is a no-op against existing locks.
  interface_lock_notes = {
    CanNotDelete = "Cannot delete the resource or its child resources."
    ReadOnly     = "Cannot delete or modify the resource or its child resources."
  }
}
