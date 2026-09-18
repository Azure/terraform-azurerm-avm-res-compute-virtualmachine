variable "location" {
  type        = string
  description = <<DESCRIPTION
`location` - (Required): The Azure Region where the Virtual Machine Run Command should exist. Changing this forces a new Virtual Machine Run Command to be created.
DESCRIPTION
  nullable    = false
}

variable "name" {
  type        = string
  description = <<DESCRIPTION
`name` - (Required): Specifies the name of this Virtual Machine Run Command. Changing this forces a new Virtual Machine Run Command to be created.
DESCRIPTION
  nullable    = false
}

variable "script_source" {
  type = object({
    command_id = optional(string)
    script     = optional(string)
    script_uri = optional(string)
    script_uri_managed_identity = optional(object({
      client_id = optional(string)
      object_id = optional(string)
    }))
  })
  description = <<DESCRIPTION
`script_source` - (Required): A source block as defined below. The source of the run command script.
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

variable "error_blob_managed_identity" {
  type = object({
    client_id = optional(string)
    object_id = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
`error_blob_managed_identity` - (Optional): An error_blob_managed_identity block as defined below. User-assigned managed Identity that has access to errorBlobUri storage blob.
DESCRIPTION
}

variable "error_blob_uri" {
  type        = string
  default     = null
  description = <<DESCRIPTION
`error_blob_uri` - (Optional): Specifies the Azure storage blob where script error stream will be uploaded. It can be basic blob URI with SAS token.
DESCRIPTION
}

variable "ignore_body_changes" {
  type = object({
    compute_virtual_machines_run_commands = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths whose changes the AzAPI provider ignores, per resource. Paths use dot notation,
for example `properties.source`. Individual list items cannot be targeted; ignore the whole list
property instead.

Configuration changes at an ignored path are not sent to Azure until that path is removed from the
list. Because the value is held in provider-private state, a change takes effect only after an
apply.

- `compute_virtual_machines_run_commands` - Ignored body paths for the virtual machine run command.
DESCRIPTION
  nullable    = false
}

variable "output_blob_managed_identity" {
  type = object({
    client_id = optional(string)
    object_id = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
`output_blob_managed_identity` - (Optional): An output_blob_managed_identity block as defined below. User-assigned managed Identity that has access to outputBlobUri storage blob.
DESCRIPTION
}

variable "output_blob_uri" {
  type        = string
  default     = null
  description = <<DESCRIPTION
`output_blob_uri` - (Optional): Specifies the Azure storage blob where script output stream will be uploaded. It can be basic blob URI with SAS token.
DESCRIPTION
}

variable "parameters" {
  type = map(object({
    name  = string
    value = string
  }))
  default     = {}
  description = <<DESCRIPTION
`parameters` - (Optional): A map of parameter blocks as defined below. The parameters used by the script.
- `map key` (Required): A unique map key for each parameter.
  - `name` (Required): The run parameter name.
  - `value` (Required): The run parameter value.
  DESCRIPTION
}

variable "protected_parameters" {
  type = map(object({
    name  = string
    value = string
  }))
  default     = {}
  description = <<DESCRIPTION
`protected_parameters` - (Optional): A list of protected_parameter blocks as defined below. The protected parameters used by the script.
- `map key` (Required): A unique map key for each parameter.
  - `name` (Required): The run parameter name.
  - `value` (Required): The run parameter value.
DESCRIPTION
  sensitive   = true
}

variable "resource_types" {
  type = object({
    compute_virtual_machines_run_commands = optional(string, "Microsoft.Compute/virtualMachines/runCommands@2024-11-01")
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module. Each key
defaults to a tested value; supply only the keys you want to override.

- `compute_virtual_machines_run_commands` - The virtual machine run command.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every AzAPI resource managed by the module. Defaults to `null` (no
custom retry).

- `error_message_regex` - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds` - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.
DESCRIPTION
}

variable "run_as_password" {
  type        = string
  default     = null
  description = <<DESCRIPTION
`run_as_password` - (Optional): Specifies the user account password on the VM when executing the Virtual Machine Run Command.
DESCRIPTION
  sensitive   = true
}

variable "run_as_user" {
  type        = string
  default     = null
  description = <<DESCRIPTION
`run_as_user` - (Optional): Specifies the user account on the VM when executing the Virtual Machine Run Command.
DESCRIPTION
  sensitive   = true
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
