variable "environment" {
  type = object({
    attached_os_disk_id = string
    location            = string
    resource_group_id   = string
    resource_group_name = string
    sku_size            = string
    subnet_id           = string
    suffix              = string
    zone                = string
  })
  description = "The shared resources created by the setup run."
  nullable    = false
}

variable "source_image_references" {
  type = map(object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  }))
  description = "The image each machine is built from, keyed by OS type. Attach mode ignores it."
  nullable    = false
}

variable "virtual_machines" {
  type = map(object({
    name           = string
    os_type        = string
    attach_os_disk = optional(bool, false)
    delete_option  = optional(string)
  }))
  description = "The machines under test, keyed by scenario. v0.21.0 has no delete_option, so it is ignored here."
  nullable    = false
}
