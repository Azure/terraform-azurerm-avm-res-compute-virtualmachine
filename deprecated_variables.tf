variable "admin_password" {
  type        = string
  default     = null
  description = "DEPRECATED:  This input has been moved to `account_credentials.admin_credentials.password` and will be removed with the release of version v1.0.0. Password to use for the default admin account created for the virtual machine. Passing this as a key vault secret value is recommended."
  sensitive   = true
}

variable "admin_ssh_keys" {
  type = list(object({
    public_key = string
    username   = string
  }))
  default     = []
  description = <<ADMIN_SSH_KEYS
DEPRECATED:  This input has been moved to `account_credentials.admin_credentials.ssh_keys` and will be removed with the release of version v1.0.0.
A list of objects defining one or more ssh public keys

- `public_key` (Required) - The Public Key which should be used for authentication, which needs to be at least 2048-bit and in `ssh-rsa` format. Changing this forces a new resource to be created.
- `username` (Required) - The Username for which this Public SSH Key should be configured. Changing this forces a new resource to be created. The Azure VM Agent only allows creating SSH Keys at the path `/home/{admin_username}/.ssh/authorized_keys`. As such this public key will be written to the authorized keys file. If no username is provided this module will use var.admin_username.

Example Input:

```hcl
admin_ssh_keys = [
  {
    public_key = "<base64 string for the key>"
    username   = "exampleuser"
  },
  {
    public_key = "<base64 string for the next user key>"
    username   = "examleuser2"
  }
]
```
  ADMIN_SSH_KEYS
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = "DEPRECATED:  This input has been moved to `account_credentials.admin_credentials.username` and will be removed with the release of version v1.0.0. Name to use for the default admin account created for the virtual machine"
  nullable    = false

  validation {
    condition     = !can(regex("^(administrator|admin|user|user1|test|user2|test2|user3|admin1|1|123|a|actuser|adm|admin2|aspnet|backup|console|david|guest|john|owner|root|server|sql|support|support_388945a0|sys|test2|test3|user4|user5)$", lower(var.admin_username)))
    error_message = "Admin username may not contain any of the following reserved values. ( administrator, admin, user, user1, test, user2, test1, user3, admin1, 1, 123, a, actuser, adm, admin2, aspnet, backup, console, david, guest, john, owner, root, server, sql, support, support_388945a0, sys, test2, test3, user4, user5 )"
  }
  validation {
    condition     = can(regex("^.{1,64}$", var.admin_username))
    error_message = "Admin username for linux must be between 1 and 64 characters in length. Admin name for windows must be between 1 and 20 characters in length."
  }
}

variable "disable_password_authentication" {
  type        = bool
  default     = true
  description = "DEPRECATED:  This input has been moved to `account_credentials.password_authentication_disabled` and will be removed with the release of version v1.0.0. If true this value will disallow password authentication on linux vm's. This will require at least one public key to be configured. If using the option to auto generate passwords and keys, setting this value to `false` will cause a password to be generated an stored instead of an SSH key."
  nullable    = false
}

variable "generate_admin_password_or_ssh_key" {
  type        = bool
  default     = true
  description = "DEPRECATED:  The logic behind this input has been moved to `account_credentials`. This input will be removed with the release of version v1.0.0. Set this value to true if the deployment should create a strong password for the admin user. If `os_type` is Linux, this will generate and store an SSH key as the default. However, setting `disable_password_authentication` to `false` will generate and store a password value instead of an ssh key."
}

variable "generated_secrets_key_vault_secret_config" {
  type = object({
    key_vault_resource_id          = string
    name                           = optional(string, null)
    expiration_date_length_in_days = optional(number, 45)
    content_type                   = optional(string, "text/plain")
    not_before_date                = optional(string, null)
    tags                           = optional(map(string), {})
  })
  default     = null
  description = <<DESCRIPTION
DEPRECATED:  The logic behind this input has been consolidated to `account_credentials.key_vault_configuration` to locate all credential related input into a single interface and help minimize configuration issues. This input will be removed with the release of version v1.0.0
For simplicity this module provides the option to use an auto-generated admin user password or SSH key.  That password or key is then stored in a key vault provided in the `admin_credential_key_vault_resource_id` input. This variable allows the user to override the configuration for the key vault secret which stores the generated password or ssh key. The object details are:

- `name` - (Optional) - The name to use for the key vault secret that stores the auto-generated ssh key or password
- `expiration_date_length_in_days` - (Optional) - This value sets the number of days from the installation date to set the key vault expiration value. It defaults to `45` days.  This value will not be overridden in subsequent runs. If you need to maintain this virtual machine resource for a long period, generate and/or use your own password or ssh key.
- `content_type` - (Optional) - This value sets the secret content type.  Defaults to `text/plain`
- `not_before_date` - (Optional) - The UTC datetime (Y-m-d'T'H:M:S'Z) date before which this key is not valid.  Defaults to null.
- `tags` - (Optional) - Specific tags to assign to this secret resource
DESCRIPTION
}
