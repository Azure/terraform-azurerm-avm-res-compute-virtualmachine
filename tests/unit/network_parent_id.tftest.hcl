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
mock_provider "azurerm" {}
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
  name                = "vm-parent-id"
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
          private_ip_subnet_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
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

run "subscription_is_derived_from_the_subnet_when_parent_id_is_omitted" {
  command = apply

  assert {
    condition     = local.subscription_id == "11111111-1111-1111-1111-111111111111"
    error_message = "The subscription must be taken from the subnet resource ID, which Azure guarantees shares the interface's subscription."
  }
  assert {
    condition     = azapi_resource.virtualmachine_network_interfaces["nic1"].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test"
    error_message = "The interface parent must combine the derived subscription with resource_group_name."
  }
}

run "explicit_parent_id_wins_over_the_derived_value" {
  command = apply

  variables {
    parent_id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-explicit"
  }

  assert {
    condition     = azapi_resource.virtualmachine_network_interfaces["nic1"].parent_id == "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-explicit"
    error_message = "A supplied parent_id must be used verbatim."
  }
}

run "per_interface_resource_group_overrides_the_parent" {
  command = apply

  variables {
    parent_id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-explicit"
    network_interfaces = {
      nic1 = {
        name                = "nic-test"
        resource_group_name = "rg-interface"
        ip_configurations = {
          ipconfig1 = {
            name                          = "ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.virtualmachine_network_interfaces["nic1"].parent_id == "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-interface"
    error_message = "A per-interface resource_group_name must replace the resource group while keeping the parent_id subscription."
  }
}

run "a_malformed_parent_id_is_rejected" {
  command = plan

  variables {
    parent_id = "/subscriptions/22222222-2222-2222-2222-222222222222"
  }

  expect_failures = [var.parent_id]
}

run "an_interface_without_a_subnet_or_parent_id_is_rejected" {
  command = plan

  variables {
    network_interfaces = {
      nic1 = {
        name = "nic-test"
        ip_configurations = {
          ipconfig1 = {
            name = "ipconfig1"
          }
        }
      }
    }
  }

  expect_failures = [azapi_resource.virtualmachine_network_interfaces]
}
