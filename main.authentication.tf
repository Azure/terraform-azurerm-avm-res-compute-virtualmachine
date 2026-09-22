####Admin password related Resources
# The expiration is anchored once, when the secret is first created, and then stays put. Deriving it
# from timestamp() on every plan is why the azurerm resource had to ignore expiration_date outright;
# azapi_data_plane_resource has no ignore_body_changes, so the value has to be stable on its own.
# Changing the configured length moves the anchor and updates the secret, which the old
# ignore_changes silently refused to do.
resource "time_offset" "credential_secret_expiration" {
  count = local.credential_secret_vault_count

  offset_days = local.credential_secret_expiration_days
}

#generate the initial admin password if requested

#scenarios:
#Linux, password auth disabled, gen ssh - false
#Linux, password auth enabled, gen ssh - true
#Linux, Password auth disabled, no gen ssh - false
#Linux, Password auth enabled, no gen ssh - false
#Windows, password auth disabled (no action), gen password - true
#Windows, password auth enabled (no action), gen password - true
#Windows, Password auth disabled (no action), no gen password - false
#Windows, password auth enabled (noaction), no gen password - false
resource "random_password" "admin_password" {
  count = local.generate_random_password_count

  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
  special          = true
}

#store the initial password in the secrets key vault
#Requires that the deployment user has key vault secrets write access
resource "azapi_data_plane_resource" "admin_password" {
  count = local.password_secret_count

  name                   = local.credential_secret_name_password
  parent_id              = local.credentials_key_vault_host
  type                   = var.resource_types.keyvault_vaults_secrets
  body                   = local.credential_secret_body
  response_export_values = []
  retry                  = var.retry
  sensitive_body = {
    value = coalesce(local.admin_password_windows, local.admin_password_linux, "notset")
  }
  # `value` is write-only, so the provider cannot see the secret change and would never send an
  # update on its own. A hash stands in for it: it moves exactly when the credential moves, without
  # the credential itself entering state. The azurerm provider held the value in state in plaintext,
  # so this is strictly less exposure than before.
  sensitive_body_version = {
    value = sha256(coalesce(local.admin_password_windows, local.admin_password_linux, "notset"))
  }

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

####Admin SSH key generation related resources
#create an ssh key for the admin user in linux
resource "tls_private_key" "this" {
  count = local.generate_admin_ssh_key_count

  algorithm = "RSA"
  rsa_bits  = 4096
}

#Store the created ssh key in the secrets key vault - does not make sense to store public keys in the vault as they can't be used to login and we don't ask for private keys outside of the generation of one.
resource "azapi_data_plane_resource" "admin_ssh_key" {
  count = local.ssh_secret_count

  name                   = local.credential_secret_name_ssh_key
  parent_id              = local.credentials_key_vault_host
  type                   = var.resource_types.keyvault_vaults_secrets
  body                   = local.credential_secret_body
  response_export_values = []
  retry                  = var.retry
  sensitive_body = {
    value = local.admin_ssh_key_secret_value
  }
  # See the note on azapi_data_plane_resource.admin_password.
  sensitive_body_version = {
    value = sha256(local.admin_ssh_key_secret_value)
  }

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

moved {
  from = azurerm_role_assignment.system_managed_identity
  to   = azapi_resource.system_managed_identity_role_assignments
}

#assign permissions to the managed identity if enabled and role assignments included
resource "azapi_resource" "system_managed_identity_role_assignments" {
  for_each = var.role_assignments_system_managed_identity

  name                 = module.avm_utl_interfaces.role_assignments_azapi["smi-${each.key}"].name
  parent_id            = each.value.scope_resource_id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_utl_interfaces.role_assignments_azapi["smi-${each.key}"].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_null_property = true
  # Azure cannot change the principal or role definition of an existing role assignment, and the
  # azurerm resource treated both as ForceNew. The generated name is stable across such a change, so
  # without this the module would plan an in-place update that Azure rejects.
  replace_triggers_refs  = ["properties.principalId", "properties.roleDefinitionId"]
  response_export_values = []
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

  lifecycle {
    # See the note on azapi_resource.disks_role_assignments: the generated GUID name would force a
    # replacement, and deleting an assignment under a CanNotDelete lock fails with ScopeLocked.
    ignore_changes = [name]
  }
}

moved {
  from = azurerm_role_assignment.this_virtual_machine
  to   = azapi_resource.this_virtual_machine_role_assignments
}

#assign permissions to the virtual machine if enabled and role assignments included
resource "azapi_resource" "this_virtual_machine_role_assignments" {
  for_each = var.role_assignments

  name                 = module.avm_utl_interfaces.role_assignments_azapi["vm-${each.key}"].name
  parent_id            = local.virtualmachine_resource_id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_utl_interfaces.role_assignments_azapi["vm-${each.key}"].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_null_property = true
  # Azure cannot change the principal or role definition of an existing role assignment, and the
  # azurerm resource treated both as ForceNew. The generated name is stable across such a change, so
  # without this the module would plan an in-place update that Azure rejects.
  replace_triggers_refs  = ["properties.principalId", "properties.roleDefinitionId"]
  response_export_values = []
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

  lifecycle {
    # See the note on azapi_resource.disks_role_assignments: the generated GUID name would force a
    # replacement, and deleting an assignment under a CanNotDelete lock fails with ScopeLocked.
    ignore_changes = [name]
  }
}
