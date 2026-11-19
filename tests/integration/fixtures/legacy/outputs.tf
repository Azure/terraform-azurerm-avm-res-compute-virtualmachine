output "resource_ids" {
  description = "The resource ID of each machine, keyed by scenario."
  value       = { for key, vm in module.virtual_machine : key => vm.resource_id }
}

output "virtual_machines" {
  description = "What Azure reports for each machine, keyed by scenario."
  value       = { for key, vm in data.azapi_resource.virtual_machine : key => vm.output }
}
