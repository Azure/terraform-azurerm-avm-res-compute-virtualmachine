mock_provider "azapi" {}
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
    condition     = azurerm_network_interface_application_gateway_backend_address_pool_association.this["primary-primary-shared"].network_interface_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vm/providers/Microsoft.Network/networkInterfaces/nic-vm"
    error_message = "The association must update the NIC in the VM subscription."
  }
  assert {
    condition     = azurerm_network_interface_application_gateway_backend_address_pool_association.this["primary-primary-shared"].backend_address_pool_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-gateway/providers/Microsoft.Network/applicationGateways/agw-shared/backendAddressPools/pool-shared"
    error_message = "The association must preserve the full backend pool resource ID from the Application Gateway subscription."
  }
}
