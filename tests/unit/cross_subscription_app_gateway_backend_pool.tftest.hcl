mock_provider "azapi" {
  # The virtual machine is still an azurerm resource and parses each network_interface_ids entry as
  # an ARM ID, so the mocked interface must carry a well-formed one rather than the generated
  # placeholder.
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
}
mock_provider "azurerm" {
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm/providers/Microsoft.Network/networkInterfaces/nic-vm"
    }
  }

  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm/providers/Microsoft.Compute/virtualMachines/vm-cross-sub"
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm/providers/Microsoft.Compute/disks/vm-cross-sub-osdisk"
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "avmUnitTest123!"
    }
  }
}
mock_provider "tls" {}

# The blanket azapi_resource mock gives every azapi resource the same id, which the still-azurerm
# resources reject when they parse it as a virtual machine ID. The virtual machine also has to
# expose an output, because the OS disk lock and network access updater read its managed disk id
# back off the created machine.
override_resource {
  target = azapi_resource.this_linux_virtual_machine
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
    output = {
      identity = {
        principalId = "11111111-1111-1111-1111-111111111111"
        tenantId    = "22222222-2222-2222-2222-222222222222"
      }
      properties = {
        vmId = "33333333-3333-3333-3333-333333333333"
        storageProfile = {
          osDisk = {
            managedDisk = {
              id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-test-osdisk"
            }
          }
        }
      }
    }
  }
}

variables {
  location            = "eastus"
  name                = "vm-cross-sub"
  resource_group_name = "rg-vm"
  zone                = "1"
  os_type             = "Linux"
  account_credentials = {
    admin_credentials = {
      generate_admin_password_or_ssh_key = true
    }
    password_authentication_disabled = false
  }
  network_interfaces = {
    primary = {
      name = "nic-vm"
      ip_configurations = {
        primary = {
          name                          = "ipconfig1"
          private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm/providers/Microsoft.Network/virtualNetworks/vnet-vm/subnets/snet-vm"
          app_gateway_backend_pools = {
            shared = {
              app_gateway_backend_pool_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-gateway/providers/Microsoft.Network/applicationGateways/agw-shared/backendAddressPools/pool-shared"
            }
          }
        }
      }
    }
  }
  source_image_reference = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

run "application_gateway_backend_pool_can_use_another_subscription" {
  command = apply

  assert {
    condition     = azapi_resource.virtualmachine_network_interfaces["primary"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm"
    error_message = "The interface must be created in the VM subscription, derived from its subnet."
  }
  assert {
    condition     = one(local.nic_bodies["primary"].properties.ipConfigurations[0].properties.applicationGatewayBackendAddressPools).id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-gateway/providers/Microsoft.Network/applicationGateways/agw-shared/backendAddressPools/pool-shared"
    error_message = "The interface body must preserve the full backend pool resource ID from the Application Gateway subscription."
  }
}
