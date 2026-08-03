# OS disk network access

This example demonstrates how to restrict network access to the virtual machine's OS disk. The VM is deployed with `public_network_access_enabled = false` and `network_access_policy = "DenyAll"` on the `os_disk` input, which blocks exporting the OS disk over the public network.

The `azurerm` provider's `os_disk` block does not expose these settings, so the module applies them to the OS disk with an `azapi_update_resource` once the virtual machine has been created.
