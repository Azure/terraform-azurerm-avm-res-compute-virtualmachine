# Azure Virtual Machine Backup Module

This module manages the Azure Backup protected item for a single virtual machine in a Recovery Services vault, independently of the virtual machine's own lifecycle.

## Features

This module supports enrolling a virtual machine into Azure Backup and managing the lifecycle of its protected item.

The module supports:

- Creating, resuming, or adopting a VM protected item in a Recovery Services vault
- Rehydrating a soft-deleted protected item before applying its configuration
- Including or excluding data disks (by LUN) from protection
- Cross-subscription vaults (the vault may live in a different subscription than the VM)
- Retaining recovery points on destroy (`ProtectionStopped`) instead of deleting the protected item

Because the protected item is managed here rather than on the virtual machine module, you can destroy or replace the virtual machine without deleting its backup data, and vice versa.

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Protect an existing virtual machine

```terraform
module "avm-res-compute-virtualmachine-backup" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm//modules/backup"

  resource_group_name        = "myrg"
  virtual_machine_name       = "myvm"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myrg/providers/Microsoft.Compute/virtualMachines/myvm"
  recovery_vault_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myrg/providers/Microsoft.RecoveryServices/vaults/myrsv"
  backup_policy_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myrg/providers/Microsoft.RecoveryServices/vaults/myrsv/backupPolicies/mypolicy"

  # Keep recovery points if this module (or the VM) is destroyed.
  retain_backup_data_on_destroy = true
}
```
