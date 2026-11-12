output "environment" {
  description = "The shared resources the machines under test are deployed into."
  value = {
    attached_os_disk_id = azapi_resource.attached_os_disk.id
    location            = var.location
    resource_group_id   = azapi_resource.resource_group.id
    resource_group_name = azapi_resource.resource_group.name
    sku_size            = module.vm_sku.sku
    subnet_id           = "${azapi_resource.virtual_network.id}/subnets/vm"
    suffix              = random_string.suffix.result
    zone                = null
  }
}
