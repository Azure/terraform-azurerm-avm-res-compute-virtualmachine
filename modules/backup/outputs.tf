output "resource_id" {
  description = "The Azure Resource ID of the backup protected item managed by this module."
  value       = local.backup_item_resource_id
}
