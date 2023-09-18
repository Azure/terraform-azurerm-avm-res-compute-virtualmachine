#get the resource group information 
data "azurerm_resource_group" "virtualmachine_deployment" {
  name = var.resource_group
}

#create the namestring
#create a random string for uniqueness during redeployments using the same values
resource "random_string" "namestring" {
  length  = 4
  special = false
  upper   = false
  lower   = true
}


####Admin password related Resources
#generate the initial admin password if requested
resource "random_password" "admin_password" {
  count = var.generate_admin_password ? 1 : 0
  length           = 22
  special          = true
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
}

#store the initial password in the secrets key vault
#Requires that the deployment user has key vault secrets write access
resource "azurerm_key_vault_secret" "admin_password" {
  count = var.generate_admin_password ? 1 : 0
  name         = "${var.virtualmachine_name}-${var.admin_username}-password"
  value        = random_password.admin_password.result
  key_vault_id = var.admin_credential_key_vault_resource_id
}

#if the password isn't being generated then get it from the key vault
data "azurerm_key_vault_secret" "admin_password" {
    count = var.generate_admin_password ? 0 : 1
    name = var.admin_password_key_vault_secret_name
    key_vault_id = var.admin_credential_key_vault_resource_id
}