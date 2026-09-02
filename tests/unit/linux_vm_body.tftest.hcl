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
  name                = "vm-body"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Linux"
  sku_size            = "Standard_D2s_v3"
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

run "core_attributes_are_mapped_to_arm_names" {
  command = apply

  assert {
    condition     = local.linux_vm_body.properties.hardwareProfile.vmSize == "Standard_D2s_v3"
    error_message = "sku_size must map to properties.hardwareProfile.vmSize."
  }
  assert {
    condition     = local.linux_vm_body.properties.osProfile.computerName == "vm-body"
    error_message = "The computer name must default to the virtual machine name."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.imageReference.publisher == "Canonical"
    error_message = "source_image_reference must map to properties.storageProfile.imageReference."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.osDisk.createOption == "FromImage"
    error_message = "A virtual machine built from an image must use the FromImage create option."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.osDisk.deleteOption == "Delete"
    error_message = "azurerm deleted the OS disk on destroy through delete_os_disk_on_deletion, so ARM must be asked to do the same or the disk is orphaned and keeps billing."
  }
  assert {
    condition     = one(local.linux_vm_body.zones) == "1"
    error_message = "zone must map to the ARM zones list."
  }
  assert {
    condition     = azapi_resource.this_linux_virtual_machine[0].type == "Microsoft.Compute/virtualMachines@2024-11-01"
    error_message = "The virtual machine must use the compute_virtual_machines resource type."
  }
}

run "the_first_interface_is_marked_primary" {
  command = apply

  variables {
    network_interfaces = {
      nic1 = {
        name       = "nic-one"
        is_primary = true
        ip_configurations = {
          ipconfig1 = {
            name                          = "ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
      }
      nic2 = {
        name = "nic-two"
        ip_configurations = {
          ipconfig1 = {
            name                          = "ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
      }
    }
  }

  assert {
    condition     = local.linux_vm_body.properties.networkProfile.networkInterfaces[0].properties.primary == true
    error_message = "ARM marks the first interface primary, so the ordered interface list must put the primary first."
  }
  assert {
    condition     = local.linux_vm_body.properties.networkProfile.networkInterfaces[1].properties.primary == false
    error_message = "Only one interface can be primary."
  }
}

run "ssh_keys_are_public_and_stay_in_the_ordinary_body" {
  command = apply

  assert {
    condition     = local.linux_vm_body.properties.osProfile.linuxConfiguration.disablePasswordAuthentication == true
    error_message = "Supplying ssh keys must disable password authentication."
  }
  assert {
    condition     = length(local.linux_vm_body.properties.osProfile.linuxConfiguration.ssh.publicKeys) == 1
    error_message = "The supplied ssh key must be carried into linuxConfiguration.ssh.publicKeys."
  }
  assert {
    condition     = local.linux_vm_body.properties.osProfile.linuxConfiguration.ssh.publicKeys[0].path == "/home/azureuser/.ssh/authorized_keys"
    error_message = "ARM addresses an ssh key by the authorized_keys path of its user."
  }
  assert {
    condition     = local.linux_vm_sensitive_body == null
    error_message = "A machine with no password and no custom data must not populate sensitive_body, so consumers on Terraform 1.10 are unaffected."
  }
}

# A password must never reach `body`, because `body` is not a sensitive attribute and would expose
# it in plan output and in state.
run "a_password_goes_to_sensitive_body_only" {
  command = apply

  variables {
    account_credentials = {
      admin_credentials = {
        generate_admin_password_or_ssh_key = false
        password                           = "P@ssw0rd1234!example"
      }
      password_authentication_disabled = false
    }
  }

  assert {
    condition     = !can(local.linux_vm_body.properties.osProfile.adminPassword)
    error_message = "The admin password must never appear in the ordinary body."
  }
  assert {
    condition     = local.linux_vm_sensitive_body.properties.osProfile.adminPassword == "P@ssw0rd1234!example"
    error_message = "The admin password must be supplied through sensitive_body."
  }
  assert {
    condition     = local.linux_vm_body.properties.osProfile.linuxConfiguration.disablePasswordAuthentication == false
    error_message = "Password authentication must be enabled when a password is supplied."
  }
  assert {
    condition     = local.linux_vm_secret_fingerprint != null
    error_message = "A fingerprint must be produced so a password change still triggers replacement."
  }
}

# merge is shallow, so a body built by merging two objects that each nest properties.osProfile
# would silently drop the first. Both secrets must survive together.
run "a_password_and_custom_data_both_survive" {
  command = apply

  variables {
    custom_data = "IyEvYmluL2Jhc2gKZWNobyBoZWxsbwo="
    account_credentials = {
      admin_credentials = {
        generate_admin_password_or_ssh_key = false
        password                           = "P@ssw0rd1234!example"
      }
      password_authentication_disabled = false
    }
  }

  assert {
    condition     = local.linux_vm_sensitive_body.properties.osProfile.adminPassword == "P@ssw0rd1234!example"
    error_message = "The admin password must survive alongside custom data."
  }
  assert {
    condition     = local.linux_vm_sensitive_body.properties.osProfile.customData == "IyEvYmluL2Jhc2gKZWNobyBoZWxsbwo="
    error_message = "Custom data must survive alongside the admin password."
  }
  assert {
    condition     = !can(local.linux_vm_body.properties.osProfile.customData)
    error_message = "Custom data must never appear in the ordinary body."
  }
}

run "guest_patching_maps_to_the_patch_settings" {
  command = apply

  variables {
    patch_mode            = "AutomaticByPlatform"
    patch_assessment_mode = "AutomaticByPlatform"
    reboot_setting        = "IfRequired"
  }

  assert {
    condition     = local.linux_vm_body.properties.osProfile.linuxConfiguration.patchSettings.patchMode == "AutomaticByPlatform"
    error_message = "patch_mode must map to linuxConfiguration.patchSettings.patchMode."
  }
  assert {
    condition     = local.linux_vm_body.properties.osProfile.linuxConfiguration.patchSettings.assessmentMode == "AutomaticByPlatform"
    error_message = "patch_assessment_mode must map to linuxConfiguration.patchSettings.assessmentMode."
  }
  assert {
    condition     = local.linux_vm_body.properties.osProfile.linuxConfiguration.patchSettings.automaticByPlatformSettings.rebootSetting == "IfRequired"
    error_message = "reboot_setting must map to the automatic by platform settings."
  }
}

run "the_automatic_by_platform_settings_are_omitted_for_other_patch_modes" {
  command = apply

  variables {
    patch_mode     = "ImageDefault"
    reboot_setting = "IfRequired"
  }

  assert {
    condition     = !can(local.linux_vm_body.properties.osProfile.linuxConfiguration.patchSettings.automaticByPlatformSettings)
    error_message = "ARM rejects the automatic by platform settings unless the patch mode is AutomaticByPlatform."
  }
}

run "optional_profiles_are_absent_when_unconfigured" {
  command = apply

  assert {
    condition     = !can(local.linux_vm_body.properties.diagnosticsProfile)
    error_message = "diagnosticsProfile must be omitted when boot diagnostics are off."
  }
  assert {
    condition     = !can(local.linux_vm_body.properties.additionalCapabilities)
    error_message = "additionalCapabilities must be omitted when not configured."
  }
  assert {
    condition     = !can(local.linux_vm_body.identity)
    error_message = "identity must be omitted when no managed identity is requested."
  }
  assert {
    condition     = !can(local.linux_vm_body.plan)
    error_message = "plan must be omitted when not supplied."
  }
  assert {
    condition     = !can(local.linux_vm_body.properties.applicationProfile)
    error_message = "applicationProfile must be omitted when no gallery applications are supplied."
  }
}

run "identity_and_boot_diagnostics_are_mapped" {
  command = apply

  variables {
    boot_diagnostics = true
    managed_identities = {
      system_assigned = true
    }
  }

  assert {
    condition     = local.linux_vm_body.identity.type == "SystemAssigned"
    error_message = "A system assigned identity must map to the ARM identity block."
  }
  assert {
    condition     = local.linux_vm_body.properties.diagnosticsProfile.bootDiagnostics.enabled == true
    error_message = "boot_diagnostics must map to diagnosticsProfile.bootDiagnostics.enabled."
  }
}

run "trusted_launch_maps_to_the_security_profile" {
  command = apply

  variables {
    secure_boot_enabled = true
    vtpm_enabled        = true
  }

  assert {
    condition     = local.linux_vm_body.properties.securityProfile.uefiSettings.secureBootEnabled == true
    error_message = "secure_boot_enabled must map to securityProfile.uefiSettings.secureBootEnabled."
  }
  assert {
    condition     = local.linux_vm_body.properties.securityProfile.uefiSettings.vTpmEnabled == true
    error_message = "vtpm_enabled must map to securityProfile.uefiSettings.vTpmEnabled."
  }
  assert {
    condition     = local.linux_vm_body.properties.securityProfile.securityType == "TrustedLaunch"
    error_message = "ARM requires a security type alongside the UEFI settings."
  }
}

# The body is a single dynamic attribute: if its shape depended on a value the caller computes,
# the whole body would be unknown at plan time and every policy check on the virtual machine would
# be blind. Only inputs decide the shape, never a computed value.
run "the_body_shape_does_not_depend_on_a_computed_zone" {
  command = apply

  variables {
    zone = null
  }

  assert {
    condition     = length(local.linux_vm_body.zones) == 0
    error_message = "A regional machine must send an empty zones list rather than changing the body's shape."
  }
  assert {
    condition     = local.linux_vm_body.properties.hardwareProfile.vmSize == "Standard_D2s_v3"
    error_message = "The rest of the body must stay readable when no zone is configured."
  }
}

# A resource id the caller computes must not decide whether a key exists. A conditional keyed on an
# unknown makes the whole merge unknown, and that hid every policy check on the machine behind an
# unknown `properties` object until it was caught by the resiliency rules.
run "resource_id_inputs_do_not_decide_the_shape_of_the_body" {
  command = apply

  assert {
    condition     = local.linux_vm_body.properties.virtualMachineScaleSet == null
    error_message = "virtual_machine_scale_set_resource_id is routinely computed, so the key must always exist and carry null when unset."
  }
  assert {
    condition     = local.linux_vm_body.properties.proximityPlacementGroup == null
    error_message = "proximity_placement_group_resource_id is routinely computed, so the key must always exist and carry null when unset."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.osDisk.managedDisk.diskEncryptionSet == null
    error_message = "os_disk.disk_encryption_set_id is routinely computed, so the key must always exist and carry null when unset."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.osDisk.managedDisk.storageAccountType == "Premium_LRS"
    error_message = "The storage account type must stay readable alongside the computed members, because the resiliency rules read it."
  }
  # Policy requires this one to be absent rather than null, so it is the deliberate exception.
  assert {
    condition     = !can(local.linux_vm_body.properties.availabilitySet)
    error_message = "availabilitySet must be omitted entirely when unset, because the resiliency rule treats a null as defined."
  }
}

# Linux has no certificate store: the certificate is written to a file, and the azurerm provider
# did not expose the field on the Linux machine at all.
run "key_vault_certificates_omit_the_certificate_store_on_linux" {
  command = apply

  variables {
    secrets = [
      {
        key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
        certificate = [
          {
            url = "https://kv-test.vault.azure.net/secrets/cert/0000"
          }
        ]
      }
    ]
  }

  assert {
    condition     = !can(local.linux_vm_body.properties.osProfile.secrets[0].vaultCertificates[0].certificateStore)
    error_message = "certificateStore is a Windows concept and must not be sent on Linux."
  }
  assert {
    condition     = local.linux_vm_body.properties.osProfile.secrets[0].vaultCertificates[0].certificateUrl == "https://kv-test.vault.azure.net/secrets/cert/0000"
    error_message = "The certificate url must still be carried on Linux."
  }
}

# ARM carries the data disks on the machine rather than as separate attachment resources. Both
# inputs feed one list, and every entry carries a name so that AzAPI matches the list by identity
# rather than by position, which is what keeps ARM's attachment order from reading as a change.
run "data_disks_are_folded_into_the_machine_and_ordered_by_lun" {
  command = apply

  variables {
    data_disk_managed_disks = {
      second = {
        name                 = "dsk-two"
        storage_account_type = "StandardSSD_LRS"
        lun                  = 2
        caching              = "ReadWrite"
        disk_size_gb         = 32
      }
      first = {
        name                 = "dsk-one"
        storage_account_type = "StandardSSD_LRS"
        lun                  = 0
        caching              = "None"
        disk_size_gb         = 32
      }
    }
    data_disk_existing_disks = {
      existing = {
        caching                  = "ReadOnly"
        lun                      = 1
        managed_disk_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/dsk-existing"
      }
    }
  }

  assert {
    condition     = length(local.linux_vm_body.properties.storageProfile.dataDisks) == 3
    error_message = "Both the disks this module creates and the disks the caller supplies belong on the machine."
  }
  assert {
    condition     = [for disk in local.linux_vm_body.properties.storageProfile.dataDisks : disk.lun] == [0, 1, 2]
    error_message = "The list must be ordered by lun so that the emitted body does not depend on how the input maps are written."
  }
  # AzAPI only accepts a string as a list identifier, so the lun cannot serve as one. Without a
  # name on every entry it falls back to comparing the list by position, and ARM returns these in
  # attachment order, which produces a diff on every plan.
  assert {
    condition     = [for disk in local.linux_vm_body.properties.storageProfile.dataDisks : disk.name] == ["dsk-one", "dsk-existing", "dsk-two"]
    error_message = "Every data disk must carry its name so that AzAPI matches the list by identity."
  }
  assert {
    condition     = alltrue([for disk in local.linux_vm_body.properties.storageProfile.dataDisks : can(tostring(disk.name)) && disk.name != ""])
    error_message = "A blank or non-string name makes AzAPI fall back to positional matching."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.dataDisks[1].managedDisk.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/dsk-existing"
    error_message = "A disk the caller already owns must be attached by its resource id."
  }
  assert {
    condition     = local.linux_vm_body.properties.storageProfile.dataDisks[0].caching == "None"
    error_message = "Each disk keeps its own caching setting after the sort."
  }
  # The disks are managed elsewhere, either by this module or by the caller, so ARM must not delete
  # them along with the machine.
  assert {
    condition     = alltrue([for disk in local.linux_vm_body.properties.storageProfile.dataDisks : disk.deleteOption == "Detach"])
    error_message = "The azurerm attachment only ever detached, so a data disk must survive the machine."
  }
  assert {
    condition     = alltrue([for disk in local.linux_vm_body.properties.storageProfile.dataDisks : disk.createOption == "Attach"])
    error_message = "disk_attachment_create_option must be carried through to the machine body."
  }
}

run "two_data_disks_cannot_share_a_lun" {
  command = plan

  variables {
    data_disk_managed_disks = {
      one = {
        name                 = "dsk-one"
        storage_account_type = "StandardSSD_LRS"
        lun                  = 0
        caching              = "ReadWrite"
        disk_size_gb         = 32
      }
    }
    data_disk_existing_disks = {
      clash = {
        caching                  = "ReadWrite"
        lun                      = 0
        managed_disk_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/dsk-existing"
      }
    }
  }

  expect_failures = [azapi_resource.this_linux_virtual_machine]
}

run "immutable_properties_force_replacement" {
  command = apply

  assert {
    condition     = contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.osProfile.adminUsername")
    error_message = "admin_username is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "zones")
    error_message = "zone is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = !contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.hardwareProfile.vmSize")
    error_message = "Resizing a virtual machine is an in-place operation and must not force replacement."
  }
}

# A body path may only be watched when the module always sends a real value for it. A path the
# module can omit, or send as null to keep the shape of the body readable, differs from the body a
# moved block adopts from Azure, and watching it replaces an adopted machine.
run "omittable_paths_are_watched_through_their_inputs" {
  command = apply

  variables {
    source_image_reference = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-focal"
      sku       = "20_04-lts-gen2"
      version   = "latest"
    }
  }

  assert {
    condition     = !contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.imageReference")
    error_message = "The image reference is sent as null in attach mode, so watching the body path would replace an adopted machine."
  }
  assert {
    condition     = !contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.osProfile.linuxConfiguration.ssh")
    error_message = "The ssh block is omitted when no keys are supplied, so watching the body path would replace an adopted machine."
  }
  assert {
    condition     = !contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.osDisk.managedDisk.securityProfile")
    error_message = "The disk security profile is sent as null when unset, so watching the body path would replace an adopted machine."
  }
  # The image is still ForceNew, it is simply watched through the input instead.
  assert {
    condition     = contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_external_values, jsonencode(local.source_image_reference))
    error_message = "source_image_reference is ForceNew under azurerm and must still replace the machine when it changes."
  }
}

# Azure fills in the OS disk name and its resource id, so both are present in the body a moved
# block adopts but absent from the body this module sends. Watching the body paths would read that
# as an immutable change and replace an adopted machine.
run "server_assigned_os_disk_values_do_not_force_replacement" {
  command = apply

  assert {
    condition     = !contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.osDisk.name")
    error_message = "Azure names the OS disk when the input is null, so the body path must not be a replacement trigger."
  }
  assert {
    condition     = !contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.osDisk.managedDisk.id")
    error_message = "Azure assigns the OS disk id for an image build, so the body path must not be a replacement trigger."
  }
}

run "the_os_disk_inputs_behind_them_still_force_replacement" {
  command = apply

  variables {
    os_disk = {
      caching              = "ReadWrite"
      storage_account_type = "Premium_LRS"
      name                 = "osdisk-explicit"
    }
  }

  assert {
    condition     = contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_external_values, "osdisk-explicit")
    error_message = "os_disk.name is ForceNew under azurerm, so changing it must still replace the machine."
  }
}

run "the_virtual_machine_azurerm_output_keeps_its_shape" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
  }

  assert {
    condition     = local.linux_virtual_machine_output_map.id == azapi_resource.this_linux_virtual_machine[0].id
    error_message = "The compatibility output must expose the virtual machine resource id."
  }
  assert {
    condition     = local.linux_virtual_machine_output_map.virtual_machine_id == "33333333-3333-3333-3333-333333333333"
    error_message = "virtual_machine_id must come from the ARM vmId, which azurerm exposed under that name."
  }
  assert {
    condition     = local.linux_virtual_machine_output_map.identity[0].principal_id == "11111111-1111-1111-1111-111111111111"
    error_message = "azurerm exposed identity as a single element list, so the shape must be preserved."
  }
}
