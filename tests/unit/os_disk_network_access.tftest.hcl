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
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-os-disk-net-access-osdisk"
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
  name                = "vm-os-disk-net-access"
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

run "os_disk_network_access_not_configured_by_default" {
  command = apply

  assert {
    condition     = length(azapi_update_resource.this_os_disk_network_access) == 0
    error_message = "The OS disk network access update resource must not be created when no os_disk network access values are supplied."
  }
}

run "os_disk_public_network_access_disabled" {
  command = apply

  variables {
    os_disk = {
      caching                       = "ReadWrite"
      storage_account_type          = "Premium_LRS"
      public_network_access_enabled = false
    }
  }

  assert {
    condition     = length(azapi_update_resource.this_os_disk_network_access) == 1
    error_message = "The OS disk network access update resource must be created when public_network_access_enabled is set."
  }
  assert {
    condition     = azapi_update_resource.this_os_disk_network_access[0].body.properties.publicNetworkAccess == "Disabled"
    error_message = "public_network_access_enabled = false must map to a publicNetworkAccess value of `Disabled`."
  }
  assert {
    condition     = !can(azapi_update_resource.this_os_disk_network_access[0].body.properties.networkAccessPolicy)
    error_message = "networkAccessPolicy must be omitted from the body when network_access_policy is not supplied."
  }
  assert {
    condition     = !can(azapi_update_resource.this_os_disk_network_access[0].body.properties.diskAccessId)
    error_message = "diskAccessId must be omitted from the body when disk_access_resource_id is not supplied."
  }
}

run "os_disk_public_network_access_enabled" {
  command = apply

  variables {
    os_disk = {
      caching                       = "ReadWrite"
      storage_account_type          = "Premium_LRS"
      public_network_access_enabled = true
    }
  }

  assert {
    condition     = azapi_update_resource.this_os_disk_network_access[0].body.properties.publicNetworkAccess == "Enabled"
    error_message = "public_network_access_enabled = true must map to a publicNetworkAccess value of `Enabled`."
  }
}

run "os_disk_private_network_access" {
  command = apply

  variables {
    os_disk = {
      caching                       = "ReadWrite"
      storage_account_type          = "Premium_LRS"
      public_network_access_enabled = false
      network_access_policy         = "AllowPrivate"
      disk_access_resource_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/diskAccesses/da-test"
    }
  }

  assert {
    condition     = azapi_update_resource.this_os_disk_network_access[0].body.properties.networkAccessPolicy == "AllowPrivate"
    error_message = "network_access_policy must be passed through to the networkAccessPolicy body property."
  }
  assert {
    condition     = azapi_update_resource.this_os_disk_network_access[0].body.properties.diskAccessId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/diskAccesses/da-test"
    error_message = "disk_access_resource_id must be passed through to the diskAccessId body property."
  }
}

run "os_disk_network_access_policy_only" {
  command = apply

  variables {
    os_disk = {
      caching               = "ReadWrite"
      storage_account_type  = "Premium_LRS"
      network_access_policy = "DenyAll"
    }
  }

  assert {
    condition     = azapi_update_resource.this_os_disk_network_access[0].body.properties.networkAccessPolicy == "DenyAll"
    error_message = "network_access_policy must be applied on its own without public_network_access_enabled."
  }
  assert {
    condition     = !can(azapi_update_resource.this_os_disk_network_access[0].body.properties.publicNetworkAccess)
    error_message = "publicNetworkAccess must be omitted from the body when public_network_access_enabled is not supplied."
  }
}

run "os_disk_invalid_network_access_policy_rejected" {
  #variable validation is evaluated during planning, so the apply can never be reached here.
  command = plan

  variables {
    os_disk = {
      caching               = "ReadWrite"
      storage_account_type  = "Premium_LRS"
      network_access_policy = "NotAPolicy"
    }
  }

  expect_failures = [var.os_disk]
}

run "os_disk_access_resource_id_requires_allow_private" {
  #variable validation is evaluated during planning, so the apply can never be reached here.
  command = plan

  variables {
    os_disk = {
      caching                 = "ReadWrite"
      storage_account_type    = "Premium_LRS"
      network_access_policy   = "DenyAll"
      disk_access_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/diskAccesses/da-test"
    }
  }

  expect_failures = [var.os_disk]
}
