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
