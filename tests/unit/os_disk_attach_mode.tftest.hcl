# Attach mode (os_disk_attach_mode / os_managed_disk_id) VMs have no osProfile in Azure, so the
# module must not send any osProfile derived attribute. The provider marks those attributes
# Optional+Computed, which means the mocked provider fills them from the `defaults` below whenever
# the module leaves them null. The defaults are therefore deliberately the opposite of the values
# fed in through `variables`, so a value that leaks through the guard is distinguishable from a
# value that was correctly nulled out.
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
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }

  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      allow_extension_operations      = true
      disable_password_authentication = true
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-attach-mode-osdisk"
      }
    }
  }

  mock_resource "azurerm_windows_virtual_machine" {
    defaults = {
      allow_extension_operations = true
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-attach-mode-osdisk"
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {
  #the generated value has to satisfy the provider side complexity check on admin_password.
  mock_resource "random_password" {
    defaults = {
      result = "avmUnitTest123!"
    }
  }
}
mock_provider "tls" {}

variables {
  location            = "eastus"
  name                = "vm-attach-mode"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Linux"
  #the sentinel input value - the mocked provider defaults above use the opposite value.
  allow_extension_operations = false
  network_interfaces = {
    network_interface_1 = {
      name = "nic-test"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "nic-test-ipconfig1"
          private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        }
      }
    }
  }
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

run "linux_attach_mode_omits_os_profile_attributes" {
  command = apply

  variables {
    os_disk_attach_mode = true
    os_managed_disk_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/disk-test"
    account_credentials = {
      admin_credentials = {
        generate_admin_password_or_ssh_key = true
      }
      password_authentication_disabled = false
    }
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this[0].allow_extension_operations == true
    error_message = "allow_extension_operations must not be sent in attach mode - updating it rewrites osProfile, which Azure rejects with 409 PropertyChangeNotAllowed on an imported VM."
  }
  assert {
    condition     = azurerm_linux_virtual_machine.this[0].disable_password_authentication == true
    error_message = "disable_password_authentication must not be sent in attach mode - it is part of osProfile and is ForceNew, so an imported VM would be planned for replacement."
  }
}

run "linux_without_attach_mode_honours_os_profile_attributes" {
  command = apply

  variables {
    os_disk_attach_mode = false
    account_credentials = {
      admin_credentials = {
        generate_admin_password_or_ssh_key = true
      }
      password_authentication_disabled = false
    }
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this[0].allow_extension_operations == false
    error_message = "allow_extension_operations must still be taken from the input variable when attach mode is not in use."
  }
  assert {
    condition     = azurerm_linux_virtual_machine.this[0].disable_password_authentication == false
    error_message = "disable_password_authentication must still be taken from the credential inputs when attach mode is not in use."
  }
}

run "windows_attach_mode_omits_os_profile_attributes" {
  command = apply

  variables {
    os_type             = "Windows"
    os_disk_attach_mode = true
    os_managed_disk_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/disk-test"
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this[0].allow_extension_operations == true
    error_message = "allow_extension_operations must not be sent in attach mode - updating it rewrites osProfile, which Azure rejects with 409 PropertyChangeNotAllowed on an imported VM."
  }
}

run "windows_without_attach_mode_honours_os_profile_attributes" {
  command = apply

  variables {
    os_type             = "Windows"
    os_disk_attach_mode = false
  }

  assert {
    condition     = azurerm_windows_virtual_machine.this[0].allow_extension_operations == false
    error_message = "allow_extension_operations must still be taken from the input variable when attach mode is not in use."
  }
}
