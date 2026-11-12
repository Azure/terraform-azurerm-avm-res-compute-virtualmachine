# The same machines as the legacy fixture, managed by this module. The inputs match, apart from
# os_disk.delete_option, which v0.21.0 does not have.
module "virtual_machine" {
  source   = "../../../.."
  for_each = var.virtual_machines

  location                   = var.environment.location
  name                       = "${each.value.name}-${var.environment.suffix}"
  resource_group_name        = var.environment.resource_group_name
  zone                       = var.environment.zone
  enable_telemetry           = false
  encryption_at_host_enabled = false
  network_interfaces = {
    primary = {
      name = "nic-${each.value.name}-${var.environment.suffix}"
      ip_configurations = {
        primary = {
          name                          = "ipconfig1"
          private_ip_subnet_resource_id = var.environment.subnet_id
        }
      }
    }
  }
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    delete_option        = each.value.delete_option
  }
  os_disk_attach_mode    = each.value.attach_os_disk
  os_managed_disk_id     = each.value.attach_os_disk ? var.environment.attached_os_disk_id : null
  os_type                = each.value.os_type
  sku_size               = var.environment.sku_size
  source_image_reference = var.source_image_references[each.value.os_type]
}

data "azapi_resource" "virtual_machine" {
  for_each = module.virtual_machine

  resource_id = each.value.resource_id
  type        = "Microsoft.Compute/virtualMachines@2024-11-01"
  response_export_values = {
    os_disk_delete_option = "properties.storageProfile.osDisk.deleteOption"
    os_disk_id            = "properties.storageProfile.osDisk.managedDisk.id"
    vm_id                 = "properties.vmId"
  }

  # A module output is not a direct reference to a managed resource, so without this the machine
  # is read while planning, before the apply has changed it.
  depends_on = [module.virtual_machine]
}
