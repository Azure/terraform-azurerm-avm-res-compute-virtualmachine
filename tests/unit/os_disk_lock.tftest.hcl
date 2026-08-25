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
      # AzAPI validates parent_id at plan time, so the mocked machine needs a well-formed resource
      # ID. The azurerm lock accepted the generated placeholder; azapi_resource does not.
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-os-disk-lock"
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-os-disk-lock-osdisk"
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}
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
  name                = "vm-os-disk-lock"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Linux"
  #a throwaway public key so the mocked tls provider doesn't have to produce a valid one.
  account_credentials = {
    admin_credentials = {
      generate_admin_password_or_ssh_key = false
      ssh_keys                           = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQChdqi+GemIsVzHEtcwAuBai8F9qfDB0vvCukphTa4WGZFJ4BJCTGhzNU3FZmBlP8/uuF8MVKXwDFsM8dSZnWldbGTBK/US6qBHK4ewu/8Fd4AqT00yPeb4354wcvyluAKqLeXh29/ILTSO/WlW4tGD/Mzx9B/qicYHyEqrYY307yAiTHps3Yi02OzG1BAprhdDz3OCyzvjgHeM8ltKokrv1/+h49oTX96pIsSVNaH6RBIsSiTSD4DAnlpeqrSacwP6az1IDFfkDob6hn2I29lJitQWuIw/Vi2hiUysPqPhs8StpXfasVfjK8NwQA0eu3KBRAGSM6OnXk+NVxeise45rjRVBKtSLd37KRQWZrOcvorlG8nZRn8TDZc8ECQbF/FJQRApT0Vf0Yxf1sdEwpcNO9/o6vnhhEY4KbFbE53xQsx0+QXdQQ+Milg7F8P/lIW9/fFVBSG07kg1qtOpj4LaHxGfwFZwyCWSAvAJ13WIlomCO/HLY3aa07zO3l6jowofJzh3WVHCaGL/Gwg1KuNYS1Hi0Hu0KXwAKeS1YQnkdfaDD7Xvf2TeP3Jzis8iDWyXrZav1XVgtOcDsOkQ3lTkdhunRGyOeqCJrxBvCAiG+N3Lb4h09SJVOIN54lBZAUFRGWjbmawNPfQkTYt8asep/yrLsfokyrBlei6rdacHPQ== avm-unit-test"]
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
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

run "os_disk_lock_not_created_by_default" {
  command = apply

  assert {
    condition     = length(azapi_resource.this_os_disk_lock) == 0
    error_message = "The OS disk lock must not be created when os_disk lock_level is not supplied."
  }
}

run "os_disk_lock_is_not_inherited_from_the_resource_level_lock" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
    }
  }

  assert {
    condition     = length(azapi_resource.this_os_disk_lock) == 0
    error_message = "The OS disk lock must not be inherited from the resource level lock variable."
  }
}

run "os_disk_lock_cannot_delete" {
  command = apply

  variables {
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
      lock_level           = "CanNotDelete"
    }
  }

  assert {
    condition     = length(azapi_resource.this_os_disk_lock) == 1
    error_message = "The OS disk lock must be created when os_disk lock_level is supplied."
  }
  assert {
    condition     = azapi_resource.this_os_disk_lock[0].body.properties.level == "CanNotDelete"
    error_message = "The OS disk lock must use the supplied lock_level."
  }
  assert {
    condition     = azapi_resource.this_os_disk_lock[0].name == "vm-os-disk-lock-os-disk-lock"
    error_message = "The OS disk lock name must be generated from the virtual machine name when lock_name is not supplied."
  }
  assert {
    condition     = azapi_resource.this_os_disk_lock[0].parent_id == azapi_resource.this_linux_virtual_machine[0].output.properties.storageProfile.osDisk.managedDisk.id && azapi_resource.this_os_disk_lock[0].parent_id != azapi_resource.this_linux_virtual_machine[0].id
    error_message = "The OS disk lock must be scoped to the OS disk resource id, not the virtual machine."
  }
}

run "os_disk_lock_read_only_with_custom_name" {
  command = apply

  variables {
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
      lock_level           = "ReadOnly"
      lock_name            = "custom-os-disk-lock"
    }
  }

  assert {
    condition     = azapi_resource.this_os_disk_lock[0].body.properties.level == "ReadOnly"
    error_message = "The OS disk lock must support a ReadOnly lock level."
  }
  assert {
    condition     = azapi_resource.this_os_disk_lock[0].name == "custom-os-disk-lock"
    error_message = "The OS disk lock must use the supplied lock_name when one is provided."
  }
}

run "os_disk_invalid_lock_level_rejected" {
  #variable validation is evaluated during planning, so the apply can never be reached here.
  command = plan

  variables {
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
      lock_level           = "None"
    }
  }

  expect_failures = [var.os_disk]
}

run "os_disk_lock_name_requires_lock_level" {
  #variable validation is evaluated during planning, so the apply can never be reached here.
  command = plan

  variables {
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
      lock_name            = "orphaned-lock-name"
    }
  }

  expect_failures = [var.os_disk]
}
