# AzAPI marks a resource's output unknown in every plan that changes the resource, even a plan that only
# changes a tag. The values below are assigned by Azure. They only change when the virtual machine is
# replaced or its system-assigned identity is switched on or off, so a copy is kept here that stays
# known through in-place updates. Without it, every update to the machine would replace the OS disk
# lock and its network access settings, show changes on the system-assigned identity's role
# assignments, and leave the identity and machine ID outputs unknown, which in turn changes anything a
# consumer builds from those outputs.
resource "terraform_data" "virtual_machine_assigned_values" {
  input = {
    os_disk_id   = (lower(var.os_type) == "windows") ? try(azapi_resource.this_windows_virtual_machine[0].output.properties.storageProfile.osDisk.managedDisk.id, null) : try(azapi_resource.this_linux_virtual_machine[0].output.properties.storageProfile.osDisk.managedDisk.id, null)
    principal_id = (lower(var.os_type) == "windows") ? try(azapi_resource.this_windows_virtual_machine[0].output.identity.principalId, null) : try(azapi_resource.this_linux_virtual_machine[0].output.identity.principalId, null)
    tenant_id    = (lower(var.os_type) == "windows") ? try(azapi_resource.this_windows_virtual_machine[0].output.identity.tenantId, null) : try(azapi_resource.this_linux_virtual_machine[0].output.identity.tenantId, null)
    vm_id        = (lower(var.os_type) == "windows") ? try(azapi_resource.this_windows_virtual_machine[0].output.properties.vmId, null) : try(azapi_resource.this_linux_virtual_machine[0].output.properties.vmId, null)
  }
  # The machine's ID stays known through in-place updates and is only unknown when the machine is
  # replaced, so it doubles as the signal that the machine is being replaced. Resources that only
  # need to follow a replacement trigger on triggers_replace.virtual_machine_id rather than on this
  # resource, which an identity change also replaces.
  triggers_replace = {
    system_assigned    = var.managed_identities.system_assigned
    virtual_machine_id = local.virtualmachine_resource_id
  }

  lifecycle {
    ignore_changes = [input]
  }
}
