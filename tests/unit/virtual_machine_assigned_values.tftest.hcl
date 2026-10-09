mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
}
mock_provider "azurerm" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "time" {}
mock_provider "tls" {}

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
  name                = "vm-assigned"
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
    nic1 = {
      name = "nic-test"
      ip_configurations = {
        ipconfig1 = {
          name                          = "ipconfig1"
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

# AzAPI marks the virtual machine's output unknown in any plan that changes the machine. The module
# reads these values through a copy that only refreshes when the machine is replaced or its
# system-assigned identity is switched on or off, so that they stay known through in-place updates.
run "the_assigned_values_are_copied_from_the_machine" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
      lock_level           = "CanNotDelete"
    }
  }

  assert {
    condition     = terraform_data.virtual_machine_assigned_values.output.os_disk_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-test-osdisk"
    error_message = "The copy must hold the OS disk ID read back off the virtual machine."
  }
  assert {
    condition     = azapi_resource.this_os_disk_lock[0].parent_id == terraform_data.virtual_machine_assigned_values.output.os_disk_id
    error_message = "The OS disk lock must be scoped through the copy, so an in-place update to the machine leaves it alone."
  }
  assert {
    condition     = output.system_assigned_mi_principal_id == "11111111-1111-1111-1111-111111111111"
    error_message = "The principal ID output must come through the copy."
  }
  assert {
    condition     = local.linux_virtual_machine_output_map.identity[0].tenant_id == "22222222-2222-2222-2222-222222222222"
    error_message = "The identity's tenant ID must come through the copy."
  }
  assert {
    condition     = local.linux_virtual_machine_output_map.virtual_machine_id == "33333333-3333-3333-3333-333333333333"
    error_message = "The machine's vmId must come through the copy."
  }
}

run "the_copy_is_refreshed_when_the_machine_or_its_identity_is_replaced" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
  }

  assert {
    condition     = terraform_data.virtual_machine_assigned_values.triggers_replace.virtual_machine_id == azapi_resource.this_linux_virtual_machine[0].id
    error_message = "The copy must be keyed to the machine's ID, which is only unknown when the machine is replaced."
  }
  assert {
    condition     = terraform_data.virtual_machine_assigned_values.triggers_replace.system_assigned == true
    error_message = "The copy must be keyed to whether the machine has a system-assigned identity, because switching it on or off changes the principal ID."
  }
}

run "the_principal_output_is_empty_without_a_system_assigned_identity" {
  command = apply

  assert {
    condition     = output.system_assigned_mi_principal_id == ""
    error_message = "Without a system-assigned identity the principal ID output must stay an empty string, as it was before."
  }
  assert {
    condition     = local.system_managed_identity_id == null
    error_message = "Without a system-assigned identity no principal ID may reach the role assignments, even if Azure reports one."
  }
}
