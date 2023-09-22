####Admin password related Resources
#generate the initial admin password if requested
resource "random_password" "admin_password" {
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
  name         = "${var.virtualmachine_name}-${var.admin_username}-password"
  value        = random_password.admin_password.result
  key_vault_id = var.admin_credential_key_vault_resource_id
}

#if the password isn't being generated or input directly then get it from the key vault
data "azurerm_key_vault_secret" "admin_password" {
  count        = var.generate_admin_password_or_ssh_key == false && var.admin_password == null ? 1 : 0
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
  name         = "${var.virtualmachine_name}-${var.admin_username}-ssh-private-key"
  value        = tls_private_key.this[0].private_key_pem
  key_vault_id = var.admin_credential_key_vault_resource_id
}

#assign permissions to the managed identity if enabled and role assignments included
resource "azurerm_role_assignment" "system_managed_identity" {
  for_each = { for assignment in var.system_managed_identity_role_assignments : assignment.scope_resource_id => assignment }

  scope                            = each.value.scope_resource_id
  principal_id                     = local.system_managed_identity_id
  name                             = each.value.name
  role_definition_id               = each.value.role_definition_resource_id
  role_definition_name             = each.value.role_definition_name
  condition                        = each.value.condition
  condition_version                = each.value.condition_version
  description                      = each.value.description
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check
}
