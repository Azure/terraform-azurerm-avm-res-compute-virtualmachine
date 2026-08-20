mock_provider "azapi" {}
mock_provider "azurerm" {
  # AzAPI validates parent_id at plan time, so every mocked resource that becomes a parent must
  # carry a well-formed ARM ID rather than the generated placeholder.
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
  mock_resource "azurerm_managed_disk" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/disk-test"
    }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-locks"
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-locks-osdisk"
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "tls" {}

variables {
  location            = "eastus"
  name                = "vm-locks"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Linux"
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

run "no_locks_created_by_default" {
  command = apply

  assert {
    condition     = length(azapi_resource.this_nic_lock) == 0 && length(azapi_resource.this_disk_lock) == 0 && length(azapi_resource.this_linux_virtualmachine_lock) == 0
    error_message = "No locks must be created when no lock levels are supplied."
  }
}

run "virtual_machine_lock_carries_notes" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
    }
  }

  assert {
    condition     = length(azapi_resource.this_linux_virtualmachine_lock) == 1
    error_message = "A Linux virtual machine lock must be created when the lock variable is supplied."
  }
  assert {
    condition     = azapi_resource.this_linux_virtualmachine_lock[0].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-locks"
    error_message = "The virtual machine lock must be parented to the virtual machine."
  }
  assert {
    condition     = azapi_resource.this_linux_virtualmachine_lock[0].body.properties.level == "CanNotDelete"
    error_message = "The lock kind must be mapped to properties.level."
  }
  assert {
    condition     = azapi_resource.this_linux_virtualmachine_lock[0].name == "lock-CanNotDelete"
    error_message = "The lock name must default to lock- followed by the kind."
  }
  assert {
    condition     = azapi_resource.this_linux_virtualmachine_lock[0].body.properties.notes == "Cannot delete the resource or its child resources."
    error_message = "The virtual machine lock must carry the CanNotDelete notes text, as the azurerm resource did."
  }
}

run "read_only_virtual_machine_lock_notes" {
  command = apply

  variables {
    lock = {
      kind = "ReadOnly"
      name = "custom-vm-lock"
    }
  }

  assert {
    condition     = azapi_resource.this_linux_virtualmachine_lock[0].name == "custom-vm-lock"
    error_message = "The lock must use the supplied name."
  }
  assert {
    condition     = azapi_resource.this_linux_virtualmachine_lock[0].body.properties.notes == "Cannot delete or modify the resource or its child resources."
    error_message = "A ReadOnly lock must carry the ReadOnly notes text."
  }
}

# The interface and disk locks never set notes on the azurerm resource. Emitting notes here would
# make the migration a real change against existing locks rather than a no-op, so their absence is
# asserted explicitly.
run "network_interface_lock_omits_notes" {
  command = apply

  variables {
    network_interfaces = {
      network_interface_1 = {
        name       = "nic-test"
        lock_level = "CanNotDelete"
        ip_configurations = {
          ip_configuration_1 = {
            name                          = "nic-test-ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.this_nic_lock["network_interface_1"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    error_message = "The interface lock must be parented to its network interface."
  }
  assert {
    condition     = azapi_resource.this_nic_lock["network_interface_1"].body.properties.level == "CanNotDelete"
    error_message = "The interface lock must use the per-interface lock level."
  }
  assert {
    condition     = azapi_resource.this_nic_lock["network_interface_1"].name == "network_interface_1-lock"
    error_message = "The interface lock name must default to the map key followed by -lock."
  }
  assert {
    condition     = !can(azapi_resource.this_nic_lock["network_interface_1"].body.properties.notes)
    error_message = "The interface lock must not emit notes, because the azurerm resource never set them."
  }
}

run "data_disk_lock_omits_notes" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        name                 = "disk-test"
        storage_account_type = "Premium_LRS"
        lun                  = 0
        caching              = "ReadWrite"
        disk_size_gb         = 32
        lock_level           = "ReadOnly"
        lock_name            = "custom-disk-lock"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_disk_lock["disk1"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/disk-test"
    error_message = "The data disk lock must be parented to its managed disk."
  }
  assert {
    condition     = azapi_resource.this_disk_lock["disk1"].body.properties.level == "ReadOnly"
    error_message = "The data disk lock must use the per-disk lock level."
  }
  assert {
    condition     = azapi_resource.this_disk_lock["disk1"].name == "custom-disk-lock"
    error_message = "The data disk lock must use the supplied lock name."
  }
  assert {
    condition     = !can(azapi_resource.this_disk_lock["disk1"].body.properties.notes)
    error_message = "The data disk lock must not emit notes, because the azurerm resource never set them."
  }
}
