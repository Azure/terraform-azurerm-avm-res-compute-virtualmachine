mock_provider "azapi" {
  # The virtual machine parses each network_interface_ids entry as
  # an ARM ID, so the mocked interface must carry a well-formed one rather than the generated
  # placeholder.
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
  # The module resolves role names to definition IDs through this data source. Without a mock its
  # output is unset and the lookup fails.
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

mock_provider "tls" {}

# A single mock_resource default applies to every azapi_resource in the module, so the data disk
# would otherwise inherit the network interface's ID and fail the azurerm attachment's ManagedDisk
# ID parser. Override the disk specifically.
override_resource {
  target = azapi_resource.this_data_disk
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/disk-test"
  }
}

# The blanket azapi_resource mock gives every azapi resource the same id, which the other
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
  name                = "vm-rbac"
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

run "no_role_assignments_created_by_default" {
  command = apply

  assert {
    condition     = length(azapi_resource.this_virtual_machine_role_assignments) == 0 && length(azapi_resource.this_network_interface_role_assignments) == 0 && length(azapi_resource.disks_role_assignments) == 0 && length(azapi_resource.system_managed_identity_role_assignments) == 0
    error_message = "No role assignments must be created when none are supplied."
  }
}

# The four collections are fed through a single interfaces module instance using owner-prefixed
# keys. These runs prove each collection reads back its own prefix and lands on the correct scope,
# which is what a prefix collision or a mis-keyed lookup would break.
run "virtual_machine_role_assignment_is_scoped_to_the_machine" {
  command = apply

  variables {
    role_assignments = {
      vm_reader = {
        role_definition_id_or_name = "Reader"
        principal_id               = "22222222-2222-2222-2222-222222222222"
        principal_type             = "User"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].parent_id == azapi_resource.this_linux_virtual_machine[0].id
    error_message = "A virtual machine role assignment must be parented to the virtual machine."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].body.properties.principalId == "22222222-2222-2222-2222-222222222222"
    error_message = "The supplied principal must be carried into the body."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "A built-in role name must be resolved to its role definition resource id."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].body.properties.principalType == "User"
    error_message = "The principal type must be carried into the body."
  }
  # AzureRM treated every input as ForceNew. Under AzAPI they live in the body and the generated name
  # is stable, so replacement has to be requested explicitly or the module plans an in-place update
  # that Azure rejects. It compares the inputs, because Azure normalises the role definition ID.
  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].replace_triggers_refs == null
    error_message = "Replacement must not compare body paths, which Azure normalises."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].replace_triggers_external_values.principal_id == "22222222-2222-2222-2222-222222222222" && azapi_resource.this_virtual_machine_role_assignments["vm_reader"].replace_triggers_external_values.role_definition_id_or_name == "reader"
    error_message = "Changing the principal or role definition must force replacement, matching the previous azurerm behaviour."
  }
}

# AzureRM matched role names case-insensitively. An exact-case lookup would pass the name through as
# the role definition ID, which plans a replacement of every upgraded assignment that Azure then
# rejects.
run "role_name_matches_case_insensitively" {
  command = apply

  variables {
    role_assignments = {
      vm_reader = {
        role_definition_id_or_name = "reader"
        principal_id               = "AAAAAAAA-2222-2222-2222-222222222222"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "A role name must resolve regardless of its casing."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].ignore_casing
    error_message = "Azure returns principal and role definition IDs in its own casing, so casing must be ignored."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].replace_triggers_external_values.principal_id == "aaaaaaaa-2222-2222-2222-222222222222"
    error_message = "A change in casing alone must not replace the assignment."
  }
}

# Azure returns tenant-level role definition IDs prefixed with the subscription of the assignment's
# scope. Sending the unprefixed form leaves a permanent difference against the deployed assignment.
run "tenant_level_role_definition_id_is_qualified" {
  command = apply

  variables {
    role_assignments = {
      vm_reader = {
        role_definition_id_or_name = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "22222222-2222-2222-2222-222222222222"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "A tenant-level role definition ID must be qualified with the subscription."
  }
}

# AzureRM sent a ServicePrincipal principal type when the check was skipped. Without it Azure looks the
# principal up in Entra ID, which fails for a service principal that has only just been created.
run "skipping_the_principal_check_sets_the_principal_type" {
  command = apply

  variables {
    role_assignments = {
      vm_reader = {
        role_definition_id_or_name       = "Reader"
        principal_id                     = "22222222-2222-2222-2222-222222222222"
        skip_service_principal_aad_check = true
      }
    }
  }

  assert {
    condition     = azapi_resource.this_virtual_machine_role_assignments["vm_reader"].body.properties.principalType == "ServicePrincipal"
    error_message = "Skipping the principal check must send the ServicePrincipal principal type."
  }
}

# A name that resolves to nothing would otherwise be sent as the role definition ID and only fail at
# apply, after any replacement had already deleted the original assignment.
run "unknown_role_name_fails_at_plan" {
  command = plan

  variables {
    role_assignments = {
      vm_unknown = {
        role_definition_id_or_name = "Not A Role"
        principal_id               = "22222222-2222-2222-2222-222222222222"
      }
    }
  }

  expect_failures = [azapi_resource.this_virtual_machine_role_assignments]
}

run "network_interface_role_assignment_is_scoped_to_the_interface" {
  command = apply

  variables {
    network_interfaces = {
      network_interface_1 = {
        name = "nic-test"
        ip_configurations = {
          ip_configuration_1 = {
            name                          = "nic-test-ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
        role_assignments = {
          nic_reader = {
            role_definition_id_or_name = "Reader"
            principal_id               = "33333333-3333-3333-3333-333333333333"
          }
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.this_network_interface_role_assignments["network_interface_1-nic_reader"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    error_message = "An interface role assignment must be parented to its network interface, not the virtual machine."
  }
  assert {
    condition     = azapi_resource.this_network_interface_role_assignments["network_interface_1-nic_reader"].body.properties.principalId == "33333333-3333-3333-3333-333333333333"
    error_message = "The interface role assignment must resolve its own entry from the merged map."
  }
}

run "data_disk_role_assignment_is_scoped_to_the_disk" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        name                 = "disk-test"
        storage_account_type = "Premium_LRS"
        lun                  = 0
        caching              = "ReadWrite"
        disk_size_gb         = 32
        role_assignments = {
          disk_reader = {
            role_definition_id_or_name = "Reader"
            principal_id               = "44444444-4444-4444-4444-444444444444"
          }
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.disks_role_assignments["disk1-disk_reader"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/disk-test"
    error_message = "A disk role assignment must be parented to its managed disk."
  }
  assert {
    condition     = azapi_resource.disks_role_assignments["disk1-disk_reader"].body.properties.principalId == "44444444-4444-4444-4444-444444444444"
    error_message = "The disk role assignment must resolve its own entry from the merged map."
  }
}

# This collection is the odd one out: the principal comes from the machine's system-assigned
# identity and the scope is an arbitrary external resource supplied per entry.
run "system_managed_identity_role_assignment_uses_the_identity_and_supplied_scope" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
    role_assignments_system_managed_identity = {
      law_reader = {
        role_definition_id_or_name = "Reader"
        scope_resource_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
      }
    }
  }

  assert {
    condition     = azapi_resource.system_managed_identity_role_assignments["law_reader"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
    error_message = "A system managed identity role assignment must be parented to the supplied scope, not the virtual machine."
  }
  # The principal itself is not asserted: it comes from the machine's identity block, and the mock
  # provider does not merge defaults into nested computed blocks, so the value here is generated
  # rather than the one supplied above.
  assert {
    condition     = azapi_resource.system_managed_identity_role_assignments["law_reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "The role name must be resolved through the same lookup as the other collections."
  }
}

# The identity's assignments may target a resource in another subscription. Azure returns the role
# definition ID in that subscription, so the ID resolved at the machine's resource group is moved into
# it.
run "system_managed_identity_role_definition_follows_the_scope_subscription" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
    role_assignments_system_managed_identity = {
      kv_reader = {
        role_definition_id_or_name = "Reader"
        scope_resource_id          = "/subscriptions/55555555-5555-5555-5555-555555555555/resourceGroups/rg-shared/providers/Microsoft.KeyVault/vaults/kv-shared"
      }
    }
  }

  assert {
    condition     = azapi_resource.system_managed_identity_role_assignments["kv_reader"].body.properties.roleDefinitionId == "/subscriptions/55555555-5555-5555-5555-555555555555/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "The role definition ID must be in the subscription of the assignment's scope."
  }
}
