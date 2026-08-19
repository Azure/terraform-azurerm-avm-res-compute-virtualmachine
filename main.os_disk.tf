locals {
  #the azurerm os_disk block doesn't expose the disk network access settings, so they are patched onto the
  #os disk created by the virtual machine resource once it exists.
  os_disk_network_access_body = {
    properties = merge(
      var.os_disk.public_network_access_enabled == null ? {} : {
        publicNetworkAccess = var.os_disk.public_network_access_enabled ? "Enabled" : "Disabled"
      },
      var.os_disk.network_access_policy == null ? {} : {
        networkAccessPolicy = var.os_disk.network_access_policy
      },
      var.os_disk.disk_access_resource_id == null ? {} : {
        diskAccessId = var.os_disk.disk_access_resource_id
      }
    )
  }
  #evaluated from variables only so that the count below is known at plan time.
  os_disk_network_access_configured = anytrue([
    var.os_disk.public_network_access_enabled != null,
    var.os_disk.network_access_policy != null,
    var.os_disk.disk_access_resource_id != null
  ])
}

resource "azapi_update_resource" "this_os_disk_network_access" {
  count = local.os_disk_network_access_configured ? 1 : 0

  resource_id            = local.os_disk_resource_id
  type                   = var.resource_types.compute_disks
  body                   = local.os_disk_network_access_body
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = ["properties.publicNetworkAccess", "properties.networkAccessPolicy", "properties.diskAccessId"]
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.this_linux,
    azurerm_virtual_machine_data_disk_attachment.this_windows
  ]
}
