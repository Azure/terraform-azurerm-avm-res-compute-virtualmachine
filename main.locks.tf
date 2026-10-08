# Azure keeps enforcing a deleted lock for a short time. The AzureRM provider waited for each lock to
# be gone before it continued, but AzAPI does not, so this pause takes its place. Every lock depends on
# it, and it depends on every resource a lock can cover. On destroy it therefore runs after the locks
# are deleted and before anything under them is, and on create the locks are applied last. There is
# one instance per lock, so removing a single lock still pauses before the resources it covered are
# deleted.
resource "time_sleep" "lock_removal" {
  for_each = local.lock_removal_keys

  destroy_duration = "30s"

  depends_on = [
    azapi_resource.disks_role_assignments,
    azapi_resource.system_managed_identity_role_assignments,
    azapi_resource.this_data_disk,
    azapi_resource.this_linux_virtual_machine,
    azapi_resource.this_maintenance_configuration_assignment,
    azapi_resource.this_network_interface_diagnostic_settings,
    azapi_resource.this_network_interface_role_assignments,
    azapi_resource.this_virtual_machine_diagnostic_settings,
    azapi_resource.this_virtual_machine_role_assignments,
    azapi_resource.this_windows_virtual_machine,
    azapi_resource.virtualmachine_network_interfaces,
    azapi_resource.virtualmachine_public_ips,
    azapi_update_resource.this_os_disk_network_access,
    module.extension,
    module.extension_1,
    module.extension_2,
    module.extension_3,
    module.extension_4,
    module.run_command,
    module.run_command_1,
    module.run_command_2,
  ]
}
