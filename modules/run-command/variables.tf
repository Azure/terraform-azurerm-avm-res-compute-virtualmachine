variable "location" {
  type        = string
  description = <<DESCRIPTION
(Required): The Azure Region where the Virtual Machine Run Command should exist. Changing this forces a new Virtual Machine Run Command to be created.
DESCRIPTION
  nullable    = false
}

variable "name" {
  type        = string
  description = <<DESCRIPTION
(Required): Specifies the name of this Virtual Machine Run Command. Changing this forces a new Virtual Machine Run Command to be created.
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
(Required): A source block as defined below. The source of the run command script.
DESCRIPTION
  nullable    = false
}

variable "virtualmachine_resource_id" {
  type        = string
  description = <<DESCRIPTION
(Required): Specifies the resource id of the Virtual Machine to apply the Run Command to.
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
(Optional): An error_blob_managed_identity block as defined below. User-assigned managed Identity that has access to errorBlobUri storage blob.
DESCRIPTION
}

variable "error_blob_uri" {
  type        = string
  default     = null
  description = <<DESCRIPTION
(Optional): Specifies the Azure storage blob where script error stream will be uploaded. It can be basic blob URI with SAS token.
DESCRIPTION
}

variable "output_blob_managed_identity" {
  type = object({
    client_id = optional(string)
    object_id = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
(Optional): An output_blob_managed_identity block as defined below. User-assigned managed Identity that has access to outputBlobUri storage blob.
DESCRIPTION
}

variable "output_blob_uri" {
  type        = string
  default     = null
  description = <<DESCRIPTION
(Optional): Specifies the Azure storage blob where script output stream will be uploaded. It can be basic blob URI with SAS token.
DESCRIPTION
}

variable "parameters" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = <<DESCRIPTION
(Optional): A list of parameter blocks as defined below. The parameters used by the script.
DESCRIPTION
}

variable "protected_parameters" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = <<DESCRIPTION
(Optional): A list of protected_parameter blocks as defined below. The protected parameters used by the script.
DESCRIPTION
  sensitive   = true
}

variable "run_as_password" {
  type        = string
  default     = null
  description = <<DESCRIPTION
(Optional): Specifies the user account password on the VM when executing the Virtual Machine Run Command.
DESCRIPTION
  sensitive   = true
}

variable "run_as_user" {
  type        = string
  default     = null
  description = <<DESCRIPTION
(Optional): Specifies the user account on the VM when executing the Virtual Machine Run Command.
DESCRIPTION
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
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
