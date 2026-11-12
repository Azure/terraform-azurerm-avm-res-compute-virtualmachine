output "os_disks_exist" {
  description = "Whether each OS disk still exists, keyed by scenario."
  value = {
    for key, id in var.os_disk_ids : key => contains([for disk_id in data.azapi_resource_list.disks.output.ids : lower(disk_id)], lower(id))
  }
}
