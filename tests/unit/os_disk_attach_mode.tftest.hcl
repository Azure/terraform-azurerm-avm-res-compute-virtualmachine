# Attach mode (os_disk_attach_mode / os_managed_disk_id) VMs have no osProfile in Azure, so the
# module must not send any osProfile derived attribute. The assertions read the request body the
# module builds, and the inputs below are deliberately the opposite of the ARM defaults so that a
# value leaking through the guard is distinguishable from one that was correctly dropped.
mock_provider "azapi" {
  # The blanket mock gives every azapi resource the same id, and the data disk attachments still
  # parse the machine id as an ARM ID, so it has to be well formed rather than a placeholder.
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

override_resource {
  target = azapi_resource.this_windows_virtual_machine
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
    condition     = !can(local.linux_vm_body.properties.osProfile)
    error_message = "osProfile must not be sent in attach mode - updating it rewrites the profile, which Azure rejects with 409 PropertyChangeNotAllowed on an imported VM."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.osDisk.createOption == "Attach"
    error_message = "An imported OS disk must be attached rather than created from an image."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.osDisk.deleteOption == "Detach"
    error_message = "A disk the caller attached belongs to them and must survive the machine."
  }
  # The key is always present so that a computed image id cannot collapse the shape of the body
  # and hide it from policy checks, so absence is expressed as a null value rather than a missing
  # key.
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.imageReference == null
    error_message = "An imported OS disk must not also carry an image reference."
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
    condition     = local.linux_vm_body.properties.osProfile.allowExtensionOperations == false
    error_message = "allow_extension_operations must still be taken from the input variable when attach mode is not in use."
  }
  assert {
    condition     = local.linux_vm_body.properties.osProfile.linuxConfiguration.disablePasswordAuthentication == false
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
    condition     = !can(local.windows_vm_body.properties.osProfile)
    error_message = "osProfile must not be sent in attach mode - updating it rewrites the profile, which Azure rejects with 409 PropertyChangeNotAllowed on an imported VM."
  }
  assert {
    condition     = local.windows_vm_sensitive_body == null
    error_message = "An imported OS disk has no admin password to set, so the sensitive body must be empty."
  }
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.osDisk.createOption == "Attach"
    error_message = "An imported OS disk must be attached rather than created from an image."
  }
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.osDisk.deleteOption == "Detach"
    error_message = "A disk the caller attached belongs to them and must survive the machine."
  }
  # The key is always present so that a computed image id cannot collapse the shape of the body
  # and hide it from policy checks, so absence is expressed as a null value rather than a missing
  # key.
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.imageReference == null
    error_message = "An imported OS disk must not also carry an image reference."
  }
}

run "windows_without_attach_mode_honours_os_profile_attributes" {
  command = apply

  variables {
    os_type             = "Windows"
    os_disk_attach_mode = false
  }

  assert {
    condition     = local.windows_vm_body.properties.osProfile.allowExtensionOperations == false
    error_message = "allow_extension_operations must still be taken from the input variable when attach mode is not in use."
  }
}
