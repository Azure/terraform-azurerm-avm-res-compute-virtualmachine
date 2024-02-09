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
  count = (
    (lower(var.virtualmachine_os_type) == "windows" && var.generate_admin_password_or_ssh_key == true) ? 1 : (
      (lower(var.virtualmachine_os_type) == "linux") && var.generate_admin_password_or_ssh_key == true && var.disable_password_authentication == false ? 1 : 0
    )
  )

  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  special          = true
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
}

#store the initial password in the secrets key vault
#Requires that the deployment user has key vault secrets write access
resource "azurerm_key_vault_secret" "admin_password" {
  count = (((var.generate_admin_password_or_ssh_key == true) && (lower(var.virtualmachine_os_type) == "windows")) ||
  ((var.generate_admin_password_or_ssh_key == true) && (lower(var.virtualmachine_os_type) == "linux") && (var.disable_password_authentication == false))) ? 1 : 0
  name         = coalesce(var.admin_password_key_vault_secret_name, "${var.name}-${var.admin_username}-password")
  value        = random_password.admin_password[0].result
  key_vault_id = var.admin_credential_key_vault_resource_id
  tags         = var.tags
}

#if the password isn't being generated or input directly then get it from the key vault
data "azurerm_key_vault_secret" "admin_password" {
  count        = var.generate_admin_password_or_ssh_key == false && var.admin_password == null && var.disable_password_authentication == false ? 1 : 0
  name         = var.admin_password_key_vault_secret_name
  key_vault_id = var.admin_credential_key_vault_resource_id
}

####Admin SSH key generation related resources
#create an ssh key for the admin user in linux
resource "tls_private_key" "this" {
  count     = ((var.generate_admin_password_or_ssh_key == true) && (lower(var.virtualmachine_os_type) == "linux")) ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}
#Store the created ssh key in the secrets key vault
resource "azurerm_key_vault_secret" "admin_ssh_key" {
  count        = ((var.generate_admin_password_or_ssh_key == true) && (lower(var.virtualmachine_os_type) == "linux")) ? 1 : 0
  name         = coalesce(var.admin_generated_ssh_key_vault_secret_name, "${var.name}-${var.admin_username}-ssh-private-key")
  value        = tls_private_key.this[0].private_key_pem
  key_vault_id = var.admin_credential_key_vault_resource_id
  tags         = var.tags
}

#assign permissions to the managed identity if enabled and role assignments included
resource "azurerm_role_assignment" "system_managed_identity" {
  for_each = var.role_assignments_system_managed_identity

  scope                                  = each.value.scope_resource_id
  principal_id                           = local.system_managed_identity_id
  role_definition_id                     = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? null : each.value.role_definition_id_or_name
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  description                            = each.value.description
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
}

#assign permissions to the virtual machine if enabled and role assignments included
resource "azurerm_role_assignment" "this_virtual_machine" {
  for_each = var.role_assignments

  scope                                  = local.virtualmachine_resource_id
  principal_id                           = each.value.principal_id
  role_definition_id                     = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = (length(split("/", each.value.role_definition_id_or_name))) > 3 ? null : each.value.role_definition_id_or_name
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  description                            = each.value.description
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
}
