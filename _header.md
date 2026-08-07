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

## Cross-subscription Application Gateway backend pools

An IP configuration can join an Application Gateway backend pool in another subscription by passing the pool's full Azure resource ID to `app_gateway_backend_pool_resource_id`. The association is written to the VM's network interface, so this module continues to use the `azurerm` provider configured for the VM subscription. A provider alias is only needed in the root configuration that reads or creates the Application Gateway.

The identity running this deployment must have the permissions Azure requires to update the NIC and reference the backend pool across subscriptions. The Application Gateway and backend networks must also have supported connectivity, such as cross-subscription VNet peering.

```hcl
provider "azurerm" {
  features {}

  subscription_id = var.vm_subscription_id
}

provider "azurerm" {
  alias = "application_gateway"

  features {}

  subscription_id = var.application_gateway_subscription_id
}

data "azurerm_application_gateway" "shared" {
  provider = azurerm.application_gateway

  name                = var.application_gateway_name
  resource_group_name = var.application_gateway_resource_group_name
}

locals {
  application_gateway_backend_pool_id = one([
    for pool in data.azurerm_application_gateway.shared.backend_address_pool : pool.id
    if pool.name == var.application_gateway_backend_pool_name
  ])
}

module "virtual_machine" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "<version>"

  # Other required VM inputs omitted for brevity.
  network_interfaces = {
    primary = {
      name = "nic-vm"
      ip_configurations = {
        primary = {
          name                          = "ipconfig1"
          private_ip_subnet_resource_id = var.vm_subnet_resource_id
          app_gateway_backend_pools = {
            shared = {
              app_gateway_backend_pool_resource_id = local.application_gateway_backend_pool_id
            }
          }
        }
      }
    }
  }
}
```

If no single deployment identity can establish the cross-subscription resource reference, configure the Application Gateway backend pool from the gateway subscription using private IP addresses or FQDNs instead of a NIC association.
