# Azure Virtual Machine Extension Module

This module is used to manage Azure Virtual Machine Extensions.

## Features

This module supports managing virtual machine extensions.

The module supports:

- Creating an extension

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Azure Monitor Agent

This example shows the most basic usage of the module.

```terraform
module "avm-res-compute-virtualmachine-extension" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm//modules/extension"

  name                       = "AzureMonitorWindowsAgent"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.Compute/virtualMachines/myVM"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.2"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  settings                   = null
}
```
