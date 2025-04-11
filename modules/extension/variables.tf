variable "name" {
  type        = string
  description = <<DESCRIPTION
`name` - (Required) - Set a custom name on this value if you want the guest configuration extension to have a custom name.
DESCRIPTION
  nullable    = false
}

variable "publisher" {
  type        = string
  description = <<DESCRIPTION
`publisher` - (Required) - Configure the publisher for the extension to be deployed. The Publisher and Type of Virtual Machine Extensions can be found using the Azure CLI, via: az vm extension image list --location westus -o table.
DESCRIPTION
  nullable    = false
}

variable "type" {
  type        = string
  description = <<DESCRIPTION
`type` - (Required) - Configure the type value for the extension to be deployed.
DESCRIPTION
  nullable    = false
}

variable "type_handler_version" {
  type        = string
  description = <<DESCRIPTION
`type_handler_version` - (Required) - The type handler version for the extension. A common value is 1.0.
DESCRIPTION
  nullable    = false
}

variable "virtualmachine_resource_id" {
  type        = string
  description = <<DESCRIPTION
`virtualmachine_resource_id` - (Required): Specifies the resource id of the Virtual Machine to apply the Run Command to.
DESCRIPTION
  nullable    = false
}

variable "auto_upgrade_minor_version" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
`auto_upgrade_minor_version` - (Optional) - Set this to false to avoid automatic upgrades for minor versions on the extension.  Defaults to true
DESCRIPTION
}

variable "automatic_upgrade_enabled" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
`automatic_upgrade_enabled` - (Optional) - Set this to false to avoid automatic upgrades for major versions on the extension.  Defaults to true
DESCRIPTION
}

variable "failure_suppression_enabled" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
`failure_suppression_enabled` - (Optional) - Should failures from the extension be suppressed? Possible values are true or false. Defaults to false. Operational failures such as not connecting to the VM will not be suppressed regardless of the failure_suppression_enabled value.
DESCRIPTION
}

variable "protected_settings" {
  type        = string
  default     = null
  description = <<DESCRIPTION
`protected_settings` - (Optional) - The protected_settings passed to the extension, like settings, these are specified as a JSON object in a string. Certain VM Extensions require that the keys in the protected_settings block are case sensitive. If you're seeing unhelpful errors, please ensure the keys are consistent with how Azure is expecting them (for instance, for the JsonADDomainExtension extension, the keys are expected to be in TitleCase.)
DESCRIPTION
  sensitive   = true
}

variable "protected_settings_from_key_vault" {
  type = object({
    secret_url      = string
    source_vault_id = string
  })
  default = {
    secret_url      = null
    source_vault_id = null
  }
  description = <<DESCRIPTION
`protected_settings_from_key_vault` - (Optional) object for protected settings.  Cannot be used with `protected_settings`
    - `secret_url` (Required) - The Secret URL of a Key Vault Certificate. This can be sourced from the `secret_id` field within the `azurerm_key_vault_certificate` Resource.
    - `source_vault_id` (Required) - the Azure resource ID of the key vault holding the secret
DESCRIPTION
}

variable "provision_after_extensions" {
  type        = list(string)
  default     = []
  description = <<DESCRIPTION
`provision_after_extensions` - (Optional) - list of strings that specifies the collection of extension names after which this extension needs to be provisioned.
DESCRIPTION
}

variable "settings" {
  type        = string
  default     = null
  description = <<DESCRIPTION
`settings` - (Optional) - The settings passed to the extension, these are specified as a JSON object in a string. Certain VM Extensions require that the keys in the settings block are case sensitive. If you're seeing unhelpful errors, please ensure the keys are consistent with how Azure is expecting them (for instance, for the JsonADDomainExtension extension, the keys are expected to be in TitleCase.)
DESCRIPTION
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "`tags` - (Optional) Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    update = optional(string)
    read   = optional(string)
  })
  default     = {}
  description = <<DESCRIPTION
An object of timeouts to apply to the creation and destruction of resources.

- `create` - (Optional) The timeout for creating the resource.
- `delete` - (Optional) The timeout for deleting the resource.
- `update` - (Optional) The timeout for updating the resource.
- `read` - (Optional) The timeout for reading the resource.

Each time duration is parsed using this function: <https://pkg.go.dev/time#ParseDuration>.
DESCRIPTION
}
