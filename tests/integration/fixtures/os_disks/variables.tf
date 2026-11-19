variable "os_disk_ids" {
  type        = map(string)
  description = "The resource IDs of the OS disks to look for, keyed by scenario."
  nullable    = false
}

variable "resource_group_id" {
  type        = string
  description = "The resource ID of the resource group the OS disks were created in."
  nullable    = false
}
