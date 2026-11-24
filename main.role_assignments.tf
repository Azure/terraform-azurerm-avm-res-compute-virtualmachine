# Role names resolve here rather than in the interfaces utility, whose lookup is case-sensitive and
# leaves tenant-level IDs unqualified. Both forms made upgraded assignments look changed and planned
# their replacement. The list is read at the resource group, whose ID is known at plan time, and the
# count reads variables only, so the lookup never waits for changes to the virtual machine.
data "azapi_resource_list" "role_definitions" {
  count = length(var.role_assignments) + length(var.role_assignments_system_managed_identity) + length(local.nics_role_assignments) + length(local.disks_role_assignments) > 0 ? 1 : 0

  parent_id = local.parent_id_for_resource_group[var.resource_group_name]
  type      = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  response_export_values = {
    results = "value[].{id: id, role_name: properties.roleName}"
  }
}
