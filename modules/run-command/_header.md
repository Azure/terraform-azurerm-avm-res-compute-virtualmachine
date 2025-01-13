# Azure Virtual Machine Run Command Module

This module is used to manage Azure Virtual Machine Run Command.

## Features

This module supports managing virtual machine run commands.

The module supports:

- Creating a run command

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Basic run command

This example shows the most basic usage of the module.

```terraform
module "avm-res-compute-virtualmachine-runcommand" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm//modules/run-command"

  name                       = "example-command"
  location                   = "uksouth"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.Compute/virtualMachines/myVM"
  script_source = {
    script = "echo Hello World"
  }
}
```
