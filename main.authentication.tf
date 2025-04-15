####Admin password related Resources
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
resource "azurerm_key_vault_secret" "admin_password" {
  count = local.password_secret_count

  key_vault_id    = local.credentials_key_vault_config.resource_id
  name            = local.credential_secret_name_password
  content_type    = local.credentials_key_vault_config.secret_configuration.content_type
  expiration_date = local.generated_secret_expiration_date_utc
  not_before_date = local.credentials_key_vault_config.secret_configuration.not_before_date
  tags            = local.credentials_key_vault_config.secret_configuration.tags != {} ? local.credentials_key_vault_config.secret_configuration.tags : var.tags
  value           = coalesce(local.admin_password_windows, local.admin_password_linux, "notset")

  lifecycle {
    ignore_changes = [expiration_date]
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
resource "azurerm_key_vault_secret" "admin_ssh_key" {
  count = local.ssh_secret_count

  key_vault_id    = local.credentials_key_vault_config.resource_id
  name            = local.credential_secret_name_ssh_key
  content_type    = local.credentials_key_vault_config.secret_configuration.content_type
  expiration_date = local.generated_secret_expiration_date_utc
  not_before_date = local.credentials_key_vault_config.secret_configuration.not_before_date
  tags            = local.credentials_key_vault_config.secret_configuration.tags != {} ? local.credentials_key_vault_config.secret_configuration.tags : var.tags
  value           = local.admin_ssh_key_secret_value

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

#assign permissions to the managed identity if enabled and role assignments included
resource "azurerm_role_assignment" "system_managed_identity" {
  for_each = var.role_assignments_system_managed_identity

  principal_id                           = local.system_managed_identity_id
  scope                                  = each.value.scope_resource_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  principal_type                         = each.value.principal_type
  role_definition_id                     = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

#assign permissions to the virtual machine if enabled and role assignments included
resource "azurerm_role_assignment" "this_virtual_machine" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = local.virtualmachine_resource_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  principal_type                         = each.value.principal_type
  role_definition_id                     = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
