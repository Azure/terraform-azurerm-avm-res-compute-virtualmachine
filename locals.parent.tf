locals {
  # parent_id MUST be known at plan time. Composing it from a data source makes it "(known after
  # apply)", which forces replacement of any resource that uses it — a destructive migration for
  # resources that already exist. The subscription is therefore taken from var.parent_id when
  # supplied, and otherwise derived from a subnet resource ID the caller already passed in. Azure
  # requires a network interface and its subnet to live in the same subscription, and every other
  # resource this module creates is deployed alongside that interface, so the derived value is
  # correct by construction rather than by assumption.
  #
  # This lives outside locals.networking.tf because the resource-group-parented resources in other
  # files (managed disks today, more later) need the same value and should not depend on the
  # networking locals to get it.
  nic_subnet_resource_ids = flatten([
    for nk, nv in var.network_interfaces : [
      for ipck, ipcv in nv.ip_configurations :
      ipcv.private_ip_subnet_resource_id if ipcv.private_ip_subnet_resource_id != null
    ]
  ])
  derived_subscription_id = length(local.nic_subnet_resource_ids) > 0 ? split("/", local.nic_subnet_resource_ids[0])[2] : null
  subscription_id         = var.parent_id != null ? split("/", var.parent_id)[2] : local.derived_subscription_id

  # Resolved defensively: when the subscription cannot be established the value stays null so the
  # resource preconditions report the problem instead of a template interpolation error.
  # `resource_group_name` is the per-resource override, falling back to the module-wide input.
  parent_id_for_resource_group = {
    for name in distinct(concat(
      [var.resource_group_name],
      [for nk, nv in var.network_interfaces : coalesce(nv.resource_group_name, var.resource_group_name)],
      [for dk, dv in var.data_disk_managed_disks : coalesce(dv.resource_group_name, var.resource_group_name)],
    )) :
    name => local.subscription_id == null ? null : "/subscriptions/${local.subscription_id}/resourceGroups/${name}"
  }
}
