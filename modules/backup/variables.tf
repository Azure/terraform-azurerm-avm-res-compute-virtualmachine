variable "recovery_vault_resource_id" {
  type        = string
  description = <<DESCRIPTION
`recovery_vault_resource_id` - (Required) - The Azure Resource ID of the recovery services vault where the backup will be stored. The vault may reside in a different subscription and resource group than the virtual machine.
DESCRIPTION
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = <<DESCRIPTION
`resource_group_name` - (Required) - The name of the resource group that contains the protected virtual machine. This value is used to compose the backup protection container and protected item names and must match the virtual machine's resource group.
DESCRIPTION
  nullable    = false
}

variable "virtual_machine_name" {
  type        = string
  description = <<DESCRIPTION
`virtual_machine_name` - (Required) - The name of the protected virtual machine. This value is used to compose the backup protection container and protected item names and must match the virtual machine's name.
DESCRIPTION
  nullable    = false
}

variable "virtualmachine_resource_id" {
  type        = string
  description = <<DESCRIPTION
`virtualmachine_resource_id` - (Required) - The full Azure Resource ID of the virtual machine to protect. Used as the `sourceResourceId` of the backup protected item, so the vault may be in a different subscription from the virtual machine.
DESCRIPTION
  nullable    = false
}

variable "backup_policy_resource_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
`backup_policy_resource_id` - (Optional) - The Azure Resource ID of the backup policy to associate with the protected item. Required when creating a protected item, but can be omitted when the protection state is `ProtectionStopped`.
DESCRIPTION
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "exclude_disk_luns" {
  type        = list(number)
  default     = null
  description = <<DESCRIPTION
`exclude_disk_luns` - (Optional) - A list of Disk Logical Unit Numbers (LUN) to be excluded from VM Protection. Only one of `exclude_disk_luns` or `include_disk_luns` can be set. If both are set then only the `exclude_disk_luns` value will be used.
DESCRIPTION
}

variable "include_disk_luns" {
  type        = list(number)
  default     = null
  description = <<DESCRIPTION
`include_disk_luns` - (Optional) - A list of Disk Logical Unit Numbers (LUN) to be included for VM Protection. Only one of `exclude_disk_luns` or `include_disk_luns` can be set. If both are set then only the `exclude_disk_luns` value will be used.
DESCRIPTION
}

variable "retain_backup_data_on_destroy" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
`retain_backup_data_on_destroy` - (Optional) - When `true`, destroying the module stops protection and retains the existing recovery points instead of deleting the protected item. Use this for immutable vaults or whenever backup data must outlive the VM. Retained backup data can continue to incur charges. Defaults to `false`.
DESCRIPTION
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "ignore_body_changes" {
  type = object({
    recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(list(string), [])
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Body-relative paths whose changes the AzAPI provider ignores, per resource. Paths use dot notation.
Configuration changes at an ignored path are not sent to Azure until that path is removed from the
list, and a change takes effect only after an apply.

This submodule manages the protected item through `azapi_resource_action` and
`azapi_update_resource`, neither of which supports `ignore_body_changes`, so the variable is
declared for interface consistency but is not currently applied to a resource.

- `recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems` - Ignored body paths for the backup protected item.
DESCRIPTION
}

variable "resource_types" {
  type = object({
    recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems = optional(string, "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-10-01")
  })
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module. Each key
defaults to a tested value; supply only the keys you want to override.

- `recoveryservices_vaults_backupfabrics_protectioncontainers_protecteditems` - The backup protected item.
DESCRIPTION
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

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every AzAPI resource managed by the module. Defaults to
`null` (provider defaults). Each value is a Go duration string, for example `30m` or `1h`.

- `create` - (Optional) Timeout for create operations.
- `read` - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
