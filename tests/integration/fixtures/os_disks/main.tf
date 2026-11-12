data "azapi_resource_list" "disks" {
  parent_id = var.resource_group_id
  type      = "Microsoft.Compute/disks@2024-03-02"
  response_export_values = {
    ids = "value[].id"
  }
}
