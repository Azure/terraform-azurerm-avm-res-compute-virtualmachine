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

run "immutable_properties_force_replacement" {
  command = apply

  assert {
    condition     = contains(azapi_resource.this_linux_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.imageReference")
    error_message = "source_image_reference is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
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
