locals {
  # Every role assignment this module manages, merged into one map so a single interfaces utility
  # instance builds every body. Keys are prefixed by owner to keep them unique; each azapi_resource
  # below still uses its own original for_each keys, so the `moved` blocks map one-to-one and consumer
  # state is preserved. scope_subscription_id is the subscription holding the assignment's scope: the
  # virtual machine's, except for the system-assigned identity's assignments, whose scope is supplied
  # per entry and may be in another subscription.
  role_assignments_requested = merge(
    { for k, v in var.role_assignments : "vm-${k}" => {
      role_definition_id_or_name             = v.role_definition_id_or_name
      principal_id                           = v.principal_id
      description                            = v.description
      skip_service_principal_aad_check       = v.skip_service_principal_aad_check
      condition                              = v.condition
      condition_version                      = v.condition_version
      delegated_managed_identity_resource_id = v.delegated_managed_identity_resource_id
      principal_type                         = v.principal_type
      scope_subscription_id                  = local.subscription_id
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
      scope_subscription_id                  = startswith(lower(v.scope_resource_id), "/subscriptions/") ? split("/", v.scope_resource_id)[2] : null
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
      scope_subscription_id                  = local.subscription_id
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
      scope_subscription_id                  = local.subscription_id
    } },
  )
  # Names match case-insensitively, as AzureRM's lookup did. A name that matches nothing is passed
  # through unchanged and stopped by each assignment's precondition.
  role_definition_ids_by_name = length(data.azapi_resource_list.role_definitions) > 0 ? {
    for definition in data.azapi_resource_list.role_definitions[0].output.results : lower(definition.role_name) => definition.id...
  } : {}
  role_definition_id_pattern         = "(?i)^(?:/subscriptions/[^/]+)?/providers/Microsoft\\.Authorization/roleDefinitions/([^/]+)$"
  role_definition_resource_substring = "/providers/microsoft.authorization/roledefinitions/"
  role_assignments_role_definition_ids = {
    for k, v in local.role_assignments_requested : k => (
      strcontains(lower(v.role_definition_id_or_name), local.role_definition_resource_substring) ? v.role_definition_id_or_name :
      try(local.role_definition_ids_by_name[lower(v.role_definition_id_or_name)][0], v.role_definition_id_or_name)
    )
  }
  interface_role_assignments = {
    for k, v in local.role_assignments_requested : k => {
      # Tenant-level and subscription-level role definition IDs are written in the subscription of the
      # assignment's scope, the form Azure returns, so the body matches the deployed assignment.
      role_definition_id_or_name = (
        can(regex(local.role_definition_id_pattern, local.role_assignments_role_definition_ids[k])) && v.scope_subscription_id != null ?
        "/subscriptions/${v.scope_subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${regex(local.role_definition_id_pattern, local.role_assignments_role_definition_ids[k])[0]}" :
        local.role_assignments_role_definition_ids[k]
      )
      principal_id                           = v.principal_id
      description                            = v.description
      skip_service_principal_aad_check       = v.skip_service_principal_aad_check
      condition                              = v.condition
      condition_version                      = v.condition_version
      delegated_managed_identity_resource_id = v.delegated_managed_identity_resource_id
      # AzureRM sent this principal type when the flag was set. It skips the Entra ID existence check
      # that fails for newly created service principals.
      principal_type = v.principal_type == null && v.skip_service_principal_aad_check ? "ServicePrincipal" : v.principal_type
    }
  }
  # AzureRM replaced an assignment whenever one of these inputs changed, and Azure rejects changing
  # the principal or role definition of an existing assignment. Replacement compares the inputs, not
  # body paths, because Azure normalises the role definition ID; AzAPI replaces nothing while the
  # prior value is null, which it is straight after the move from AzureRM.
  role_assignments_replace_triggers = {
    for k, v in local.role_assignments_requested : k => {
      condition                              = v.condition
      condition_version                      = v.condition_version
      delegated_managed_identity_resource_id = v.delegated_managed_identity_resource_id
      description                            = v.description
      principal_id                           = try(lower(v.principal_id), null)
      principal_type                         = local.interface_role_assignments[k].principal_type
      role_definition_id_or_name             = lower(v.role_definition_id_or_name)
    }
  }
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
  # The resource each lock covers, keyed by lock using the same conditions as the lock resources. The
  # keys come from variables only, so they are known at plan time. The IDs re-run the lock removal
  # pause when the covered resource is replaced, because replacing a resource replaces its lock too.
  # The OS disk is only ever replaced together with the virtual machine, and its own ID is read from
  # the machine's output, which is unknown whenever the machine changes at all, so the machine's ID
  # stands in for it.
  lock_removal_resource_ids = merge(
    var.lock != null ? { virtual_machine = local.virtualmachine_resource_id } : {},
    var.os_disk.lock_level != null ? { os_disk = local.virtualmachine_resource_id } : {},
    { for k, v in var.data_disk_managed_disks : "data_disk/${k}" => azapi_resource.this_data_disk[k].id if v.lock_level != null },
    { for k, v in var.network_interfaces : "network_interface/${k}" => azapi_resource.virtualmachine_network_interfaces[k].id if v.lock_level != null },
    { for k, v in local.nics_ip_configs : "public_ip/${k}" => azapi_resource.virtualmachine_public_ips[k].id if v.ipconfig.create_public_ip_address == true && var.public_ip_configuration_details.lock_level != null },
  )
}
