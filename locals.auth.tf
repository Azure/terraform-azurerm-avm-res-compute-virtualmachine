locals {
  admin_password_input = (var.account_credentials.admin_credentials.password != null ? var.account_credentials.admin_credentials.password : (var.admin_password != null ? var.admin_password : null))
  #set the admin password to either a generated value or the entered value
  admin_password_linux = (lower(var.os_type) == "linux") ? (
    local.password_authentication_disabled == false ? (                                                          #if os is linux and password authentication is enabled
      local.admin_password_input == null ? random_password.admin_password[0].result : local.admin_password_input #use generated password if input is null, otherwise use input password
    ) : null                                                                                                     #null value if password authentication is disabled
  ) : null                                                                                                       #null value if os is not linux
  admin_password_windows = (lower(var.os_type) == "windows") ? (
    local.admin_password_input == null ? random_password.admin_password[0].result : local.admin_password_input #use generated password if input is null, otherwise use input password
  ) : null                                                                                                     #null value if os is not windows
  # set the ssh key for the admin user in linux
  admin_ssh_key = ((local.password_authentication_disabled == true) && (lower(var.os_type) == "linux")) ? (
    length(local.admin_ssh_key_input) == 0 ? [{
      public_key = tls_private_key.this[0].public_key_openssh
      username   = local.admin_username
      }] : [
      for key in local.admin_ssh_key_input : {
        public_key = key
        username   = local.admin_username
      }
    ]
  ) : []
  #if ssh key set in multiple places, prefer the var.account_credentials value
  admin_ssh_key_input = (length(var.account_credentials.admin_credentials.ssh_keys) > 0 ? var.account_credentials.admin_credentials.ssh_keys : (length(local.deprecated_keys) > 0 ? local.deprecated_keys : []))
  #set the ssh key secret value to the generated key if password authentication is disabled and no ssh key is provided.  Otherwise, set it to "no_key" to indicate that no key was provided.
  admin_ssh_key_secret_value = ((local.password_authentication_disabled == true) && (lower(var.os_type) == "linux") && length(local.admin_ssh_key_input) == 0) ? tls_private_key.this[0].private_key_pem : "no_key"
  #concat the ssh key values list
  admin_ssh_keys = concat(var.admin_ssh_keys, local.admin_ssh_key) #set this to the local after deprecation
  #set the admin user to use the following order:
  # 1. account_credentials.username
  # 2. admin_username
  # 3. azureuser (default value if not provided))
  admin_username = var.account_credentials.admin_credentials.username != "azureuser" ? var.account_credentials.admin_credentials.username : (var.admin_username != "azureuser" ? var.admin_username : "azureuser") #both default to azureuser without input so no need for special handling.  After deprecation, set admin_username to var.account_credentials.username
  #set the name for the password secret in the key vault if the key vault secret configuration is not null and there is a password input.
  credential_secret_name_password = (
    local.credentials_key_vault_config != null ? (
      local.credentials_key_vault_config.secret_configuration != null ? (
        local.credentials_key_vault_config.secret_configuration.name != null ? local.credentials_key_vault_config.secret_configuration.name : "${var.name}-${local.admin_username}-password"
  ) : "${var.name}-${local.admin_username}-password") : "${var.name}-${local.admin_username}-password")
  #set the name for the ssh secret in the key vault if the key vault secret configuration is not null and there is a password input.
  credential_secret_name_ssh_key = (
    local.credentials_key_vault_config != null ? (
      local.credentials_key_vault_config.secret_configuration != null ? (
        local.credentials_key_vault_config.secret_configuration.name != null ? local.credentials_key_vault_config.secret_configuration.name : "${var.name}-${local.admin_username}-ssh-private-key"
  ) : "${var.name}-${local.admin_username}-ssh-private-key") : "${var.name}-${local.admin_username}-ssh-private-key")
  #use locals to define whether a secret should be created in the key vault
  credential_secret_vault_count = (                    #if the key vault config is set, then create a credential secret
    local.credentials_key_vault_config != null ? 1 : 0 #the resource_id value is a required field in both cases, so we can use that to determine if the key vault config is set.
  )
  #set the credentials key vault configuration. Prefer the var.account_credentials value if set, otherwise use the var.generated_secrets_key_vault_secret_config value.  If both are set, prefer the var.account_credentials value.
  credentials_key_vault_config = var.account_credentials.key_vault_configuration != null ? var.account_credentials.key_vault_configuration : ( #if key vault config set in multiple places, prefer the var.account_credentials value
  local.deprecated_key_vault_config != null ? local.deprecated_key_vault_config : null)
  #create a version of the old key vault config with the new schema so the ternary can be used to set the key vault config
  deprecated_key_vault_config = var.generated_secrets_key_vault_secret_config != null ? {
    resource_id = var.generated_secrets_key_vault_secret_config.key_vault_resource_id
    secret_configuration = {
      name                           = var.generated_secrets_key_vault_secret_config.name
      expiration_date_length_in_days = var.generated_secrets_key_vault_secret_config.expiration_date_length_in_days
      content_type                   = var.generated_secrets_key_vault_secret_config.content_type
      not_before_date                = var.generated_secrets_key_vault_secret_config.not_before_date
      tags                           = var.generated_secrets_key_vault_secret_config.tags
    }
  } : null
  deprecated_keys = length(var.admin_ssh_keys) > 0 ? local.flattened_ssh_keys : []
  #ssh key for handling deprecated ssh key input (the schema's are different,so we need to handle this)
  flattened_ssh_keys = flatten([for key in var.admin_ssh_keys : key.public_key])
  generate_admin_ssh_key_count = (
    (lower(var.os_type) == "linux") &&
    (
      (var.generate_admin_password_or_ssh_key == true) &&
      (var.account_credentials.admin_credentials.generate_admin_password_or_ssh_key == true)
    ) && (local.password_authentication_disabled == true) ? 1 : 0
  )
  generate_random_password_count = (
    (
      (lower(var.os_type) == "windows") &&
      (
        (var.generate_admin_password_or_ssh_key == true) &&
        (var.account_credentials.admin_credentials.generate_admin_password_or_ssh_key == true)
      )
      ) ? 1 : (
      (lower(var.os_type) == "linux") &&
      (
        (var.generate_admin_password_or_ssh_key == true && var.account_credentials.admin_credentials.generate_admin_password_or_ssh_key == true) && (local.password_authentication_disabled == false)
      )
    ) ? 1 : 0
  )
  generated_secret_expiration_date_utc = local.generated_secret_expiration_date_utc_new == null ? local.generated_secret_expiration_date_utc_depr : local.generated_secret_expiration_date_utc_new
  #calculate the expiration date for the key vault secret.  If the key vault config is set, then use that value.  Otherwise, use the default value of 45 days.
  generated_secret_expiration_date_utc_depr = local.deprecated_key_vault_config != null ? formatdate("YYYY-MM-DD'T'hh:mm:ssZ", (timeadd(timestamp(), "${local.deprecated_key_vault_config.secret_configuration.expiration_date_length_in_days * 24}h"))) : null
  generated_secret_expiration_date_utc_new  = var.account_credentials.key_vault_configuration != null ? formatdate("YYYY-MM-DD'T'hh:mm:ssZ", (timeadd(timestamp(), "${var.account_credentials.key_vault_configuration.secret_configuration.expiration_date_length_in_days * 24}h"))) : null #validate this works when expire is undefined
  password_authentication_disabled = var.account_credentials.password_authentication_disabled == false ? var.account_credentials.password_authentication_disabled : (
  var.disable_password_authentication == false ? var.disable_password_authentication : true) #defaults to true for both vars. Prefer var.account_credentials value if set, otherwise use var.disable_password_authentication.  If both are set, prefer var.account_credentials value. After deprecation, set password_authentication_disabled to var.account_credentials.password_authentication_disabled
  #set the count to 1 if a password value is provided and a secret configuration is provided or generated. This will be used to create the key vault secret.
  password_secret_count = (
    (local.credential_secret_vault_count == 1 && lower(var.os_type) == "windows") ||
    (local.credential_secret_vault_count == 1 && lower(var.os_type) == "linux" && local.password_authentication_disabled == false) ? 1 : 0
  )
  #set the count to 1 if a ssh value is provided and a secret configuration is provided or generated. This will be used to create the key vault secret.
  ssh_secret_count = (local.credential_secret_vault_count == 1 && local.generate_admin_ssh_key_count == 1) ? 1 : 0
}
