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
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-aad-ssh"
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-aad-ssh-osdisk"
      }
    }
  }

  mock_resource "azurerm_virtual_machine_extension" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-aad-ssh/extensions/AADSSHLoginForLinux"
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
  name                = "vm-aad-ssh"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Linux"
  account_credentials = {
    admin_credentials = {
      generate_admin_password_or_ssh_key = true
    }
    password_authentication_disabled = false
  }
  extensions = {
    aad_ssh_login = {
      name                       = "AADSSHLoginForLinux"
      publisher                  = "Microsoft.Azure.ActiveDirectory"
      type                       = "AADSSHLoginForLinux"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
    }
  }
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
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

run "aad_ssh_login_requires_system_assigned_identity" {
  command = plan

  expect_failures = [var.extensions]
}

run "aad_ssh_login_requires_linux" {
  command = plan

  variables {
    os_type = "Windows"
    account_credentials = {
      admin_credentials = {
        generate_admin_password_or_ssh_key = true
      }
    }
    managed_identities = {
      system_assigned = true
    }
    source_image_reference = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-g2"
      version   = "latest"
    }
  }

  expect_failures = [var.extensions]
}

run "aad_ssh_login_requires_vm_agent_and_extension_operations" {
  command = plan

  variables {
    allow_extension_operations = false
    provision_vm_agent         = false
    managed_identities = {
      system_assigned = true
    }
  }

  expect_failures = [var.extensions]
}

run "aad_ssh_login_with_required_prerequisites" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this[0].identity[0].type == "SystemAssigned"
    error_message = "The valid AAD SSH configuration must enable the VM's system-assigned managed identity."
  }
  assert {
    condition     = module.extension["aad_ssh_login"].resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-aad-ssh/extensions/AADSSHLoginForLinux"
    error_message = "The AADSSHLoginForLinux extension must be created when all prerequisites are configured."
  }
}
