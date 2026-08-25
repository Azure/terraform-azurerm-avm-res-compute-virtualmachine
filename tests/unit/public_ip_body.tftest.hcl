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
  name                = "vm-public-ip"
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
          create_public_ip_address      = true
          public_ip_address_name        = "pip-test"
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

run "public_ip_defaults_are_mapped_to_arm_names" {
  command = apply

  assert {
    condition     = local.public_ip_body.properties.publicIPAllocationMethod == "Static"
    error_message = "allocation_method must map to properties.publicIPAllocationMethod."
  }
  assert {
    condition     = local.public_ip_body.properties.publicIPAddressVersion == "IPv4"
    error_message = "ip_version must map to properties.publicIPAddressVersion."
  }
  assert {
    condition     = local.public_ip_body.properties.idleTimeoutInMinutes == 30
    error_message = "idle_timeout_in_minutes must map to properties.idleTimeoutInMinutes."
  }
  assert {
    condition     = local.public_ip_body.sku.name == "Standard" && local.public_ip_body.sku.tier == "Regional"
    error_message = "sku and sku_tier must map to the ARM sku object."
  }
  assert {
    condition     = local.public_ip_body.zones == tolist(["1", "2", "3"])
    error_message = "zones must be carried into the body as a sorted list."
  }
  assert {
    condition     = local.public_ip_body.properties.ddosSettings.protectionMode == "VirtualNetworkInherited"
    error_message = "ddos_protection_mode must map to properties.ddosSettings.protectionMode."
  }
  assert {
    condition     = !can(local.public_ip_body.properties.dnsSettings)
    error_message = "dnsSettings must be omitted when no domain_name_label is supplied."
  }
}

run "public_ip_is_created_in_the_derived_resource_group" {
  command = apply

  assert {
    condition     = azapi_resource.virtualmachine_public_ips["nic1-ipconfig1"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    error_message = "The public IP must be created in resource_group_name using the derived subscription."
  }
  assert {
    condition     = azapi_resource.virtualmachine_public_ips["nic1-ipconfig1"].name == "pip-test"
    error_message = "The public IP must use the configured public_ip_address_name."
  }
}

run "public_ip_is_attached_to_the_ip_configuration" {
  command = apply

  assert {
    condition     = local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.publicIPAddress.id == azapi_resource.virtualmachine_public_ips["nic1-ipconfig1"].id
    error_message = "A created public IP must be referenced from the interface's IP configuration."
  }
}

run "optional_public_ip_settings_are_mapped" {
  command = apply

  variables {
    public_ip_configuration_details = {
      allocation_method       = "Static"
      domain_name_label       = "vm-public-ip-label"
      ddos_protection_mode    = "Enabled"
      ddos_protection_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
      idle_timeout_in_minutes = 15
      ip_version              = "IPv4"
      sku                     = "Standard"
      sku_tier                = "Regional"
      zones                   = ["1"]
    }
  }

  assert {
    condition     = local.public_ip_body.properties.dnsSettings.domainNameLabel == "vm-public-ip-label"
    error_message = "domain_name_label must map to properties.dnsSettings.domainNameLabel."
  }
  assert {
    condition     = local.public_ip_body.properties.ddosSettings.ddosProtectionPlan.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
    error_message = "ddos_protection_plan_id must map to properties.ddosSettings.ddosProtectionPlan.id."
  }
  assert {
    condition     = local.public_ip_body.properties.idleTimeoutInMinutes == 15
    error_message = "A supplied idle_timeout_in_minutes must be carried into the body."
  }
  assert {
    condition     = local.public_ip_body.zones == tolist(["1"])
    error_message = "A supplied zone set must be carried into the body."
  }
}
