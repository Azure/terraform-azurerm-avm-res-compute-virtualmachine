# terraform-azurerm-avm-res-compute-virtualmachine

### NOTE: This module follows the semantic versioning and versions prior to 1.0.0 should be considered pre-release versions. This v0.19.0 version contains a number of breaking changes and is intended to be the final signficant release prior to the v1.0.0 release.  Please review the release notes prior to updating previous deployments to use this version.

This is the virtual machine resource module for the Azure Verified Modules library.  This module deploys a Windows and/or Linux virtual machine along with common associated resources.  It leverages the AzureRM provider and sets a number of initial defaults to minimize the overall inputs for simple configurations.

## Azure Backup lifecycle

The module manages each configured Azure VM backup protected item through its full lifecycle:

- A missing protected item is created.
- An existing active or `ProtectionStopped` item is adopted and updated.
- A soft-deleted item is automatically rehydrated before its backup configuration is applied.
- Existing protected items managed by earlier module versions are adopted without deleting their recovery points.

By default, removing a backup configuration or destroying the module deletes the protected item, matching the module's previous behavior. Set `retain_backup_data_on_destroy = true` on an `azure_backup_configurations` entry to stop protection while retaining its recovery points. This mode is intended for immutable vaults and other scenarios where backup data must outlive the virtual machine. Retained recovery points can continue to incur charges until they expire or are deleted.
