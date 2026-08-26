mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
}
mock_provider "azurerm" {}
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
  name                = "vm-body"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Windows"
  sku_size            = "Standard_D2s_v3"
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
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

run "core_attributes_are_mapped_to_arm_names" {
  command = apply

  assert {
    condition     = local.windows_vm_body.properties.hardwareProfile.vmSize == "Standard_D2s_v3"
    error_message = "sku_size must map to properties.hardwareProfile.vmSize."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.computerName == "vm-body"
    error_message = "The computer name must default to the virtual machine name."
  }
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.imageReference.publisher == "MicrosoftWindowsServer"
    error_message = "source_image_reference must map to properties.storageProfile.imageReference."
  }
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.osDisk.createOption == "FromImage"
    error_message = "A virtual machine built from an image must use the FromImage create option."
  }
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.osDisk.deleteOption == "Delete"
    error_message = "azurerm deleted the OS disk on destroy through delete_os_disk_on_deletion, so ARM must be asked to do the same or the disk is orphaned and keeps billing."
  }
  assert {
    condition     = one(local.windows_vm_body.zones) == "1"
    error_message = "zone must map to the ARM zones list."
  }
  assert {
    condition     = azapi_resource.this_windows_virtual_machine[0].type == "Microsoft.Compute/virtualMachines@2024-11-01"
    error_message = "The virtual machine must use the compute_virtual_machines resource type."
  }
  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.linuxConfiguration)
    error_message = "A Windows machine must not carry a linuxConfiguration."
  }
}

# A Windows machine always authenticates with a password, so unlike Linux the sensitive body is
# populated on every deployment that is not attaching an existing OS disk.
run "the_admin_password_goes_to_sensitive_body_only" {
  command = apply

  variables {
    account_credentials = {
      admin_credentials = {
        generate_admin_password_or_ssh_key = false
        password                           = "P@ssw0rd1234!example"
      }
    }
  }

  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.adminPassword)
    error_message = "The admin password must never appear in the ordinary body, which is not a sensitive attribute."
  }
  assert {
    condition     = local.windows_vm_sensitive_body.properties.osProfile.adminPassword == "P@ssw0rd1234!example"
    error_message = "The admin password must be supplied through sensitive_body."
  }
  assert {
    condition     = local.windows_vm_secret_fingerprint != null
    error_message = "A fingerprint must be produced so a password change still triggers replacement."
  }
}

# merge is shallow, so a body built by merging two objects that each nest properties.osProfile
# would silently drop the first. Every secret must survive together.
run "a_password_custom_data_and_unattend_content_all_survive" {
  command = apply

  variables {
    custom_data = "PHBvd2Vyc2hlbGw+ZWNobyBoZWxsbzwvcG93ZXJzaGVsbD4="
    additional_unattend_contents = [
      {
        setting = "AutoLogon"
        content = "<AutoLogon><Password><Value>P@ssw0rd1234!example</Value></Password></AutoLogon>"
      }
    ]
    account_credentials = {
      admin_credentials = {
        generate_admin_password_or_ssh_key = false
        password                           = "P@ssw0rd1234!example"
      }
    }
  }

  assert {
    condition     = local.windows_vm_sensitive_body.properties.osProfile.adminPassword == "P@ssw0rd1234!example"
    error_message = "The admin password must survive alongside the other secrets."
  }
  assert {
    condition     = local.windows_vm_sensitive_body.properties.osProfile.customData == "PHBvd2Vyc2hlbGw+ZWNobyBoZWxsbzwvcG93ZXJzaGVsbD4="
    error_message = "Custom data must survive alongside the admin password."
  }
  assert {
    condition     = local.windows_vm_sensitive_body.properties.osProfile.windowsConfiguration.additionalUnattendContent[0].content == "<AutoLogon><Password><Value>P@ssw0rd1234!example</Value></Password></AutoLogon>"
    error_message = "Unattend content routinely carries credentials and must survive alongside the other secrets."
  }
  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.customData)
    error_message = "Custom data must never appear in the ordinary body."
  }
  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.windowsConfiguration.additionalUnattendContent[0].content)
    error_message = "Only the shape of an unattend file belongs in the ordinary body, never its content."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.additionalUnattendContent[0].settingName == "AutoLogon"
    error_message = "The unattend setting name is not a secret and must stay in the ordinary body so it can be checked by policy."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.additionalUnattendContent[0].passName == "OobeSystem"
    error_message = "azurerm fixed the pass and component, and they are the only values Azure accepts."
  }
}

run "guest_patching_maps_to_the_windows_patch_settings" {
  command = apply

  variables {
    patch_mode            = "AutomaticByPlatform"
    patch_assessment_mode = "AutomaticByPlatform"
    hotpatching_enabled   = true
    reboot_setting        = "IfRequired"
  }

  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.patchSettings.patchMode == "AutomaticByPlatform"
    error_message = "patch_mode must map to windowsConfiguration.patchSettings.patchMode."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.patchSettings.assessmentMode == "AutomaticByPlatform"
    error_message = "patch_assessment_mode must map to windowsConfiguration.patchSettings.assessmentMode."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.patchSettings.enableHotpatching == true
    error_message = "hotpatching_enabled is Windows only and must map to windowsConfiguration.patchSettings.enableHotpatching."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.patchSettings.automaticByPlatformSettings.rebootSetting == "IfRequired"
    error_message = "reboot_setting must map to the automatic by platform settings."
  }
}

run "the_automatic_by_platform_settings_are_omitted_for_other_patch_modes" {
  command = apply

  variables {
    patch_mode     = "Manual"
    reboot_setting = "IfRequired"
  }

  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.windowsConfiguration.patchSettings.automaticByPlatformSettings)
    error_message = "ARM rejects the automatic by platform settings unless the patch mode is AutomaticByPlatform."
  }
}

run "windows_only_configuration_is_mapped" {
  command = apply

  variables {
    timezone                  = "Pacific Standard Time"
    provision_vm_agent        = true
    automatic_updates_enabled = true
    winrm_listeners = [
      {
        protocol = "Http"
      }
    ]
  }

  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.timeZone == "Pacific Standard Time"
    error_message = "timezone must map to windowsConfiguration.timeZone."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.provisionVMAgent == true
    error_message = "provision_vm_agent must map to windowsConfiguration.provisionVMAgent."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.enableAutomaticUpdates == true
    error_message = "automatic_updates_enabled must map to windowsConfiguration.enableAutomaticUpdates."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.winRM.listeners[0].protocol == "Http"
    error_message = "winrm_listeners must map to windowsConfiguration.winRM.listeners."
  }
  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.windowsConfiguration.winRM.listeners[0].certificateUrl)
    error_message = "An http listener has no certificate, so the certificate url must be absent rather than null."
  }
}

run "the_deprecated_automatic_updates_input_still_reaches_the_body" {
  command = apply

  variables {
    enable_automatic_updates = false
  }

  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.enableAutomaticUpdates == false
    error_message = "enable_automatic_updates is deprecated but still supported, so it must keep feeding windowsConfiguration.enableAutomaticUpdates."
  }
}

run "the_replacement_automatic_updates_input_wins" {
  command = apply

  variables {
    enable_automatic_updates  = false
    automatic_updates_enabled = true
  }

  assert {
    condition     = local.windows_vm_body.properties.osProfile.windowsConfiguration.enableAutomaticUpdates == true
    error_message = "automatic_updates_enabled takes precedence over the deprecated input."
  }
}

run "optional_profiles_are_absent_when_unconfigured" {
  command = apply

  assert {
    condition     = !can(local.windows_vm_body.properties.diagnosticsProfile)
    error_message = "diagnosticsProfile must be omitted when boot diagnostics are off."
  }
  assert {
    condition     = !can(local.windows_vm_body.properties.additionalCapabilities)
    error_message = "additionalCapabilities must be omitted when not configured."
  }
  assert {
    condition     = !can(local.windows_vm_body.identity)
    error_message = "identity must be omitted when no managed identity is requested."
  }
  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.windowsConfiguration.winRM)
    error_message = "winRM must be omitted when no listener is configured."
  }
  assert {
    condition     = !can(local.windows_vm_body.properties.osProfile.windowsConfiguration.additionalUnattendContent)
    error_message = "additionalUnattendContent must be omitted when no unattend file is supplied."
  }
}

run "trusted_launch_maps_to_the_security_profile" {
  command = apply

  variables {
    secure_boot_enabled = true
    vtpm_enabled        = true
  }

  assert {
    condition     = local.windows_vm_body.properties.securityProfile.uefiSettings.secureBootEnabled == true
    error_message = "secure_boot_enabled must map to securityProfile.uefiSettings.secureBootEnabled."
  }
  assert {
    condition     = local.windows_vm_body.properties.securityProfile.securityType == "TrustedLaunch"
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
    condition     = length(local.windows_vm_body.zones) == 0
    error_message = "A regional machine must send an empty zones list rather than changing the body's shape."
  }
  assert {
    condition     = local.windows_vm_body.properties.hardwareProfile.vmSize == "Standard_D2s_v3"
    error_message = "The rest of the body must stay readable when no zone is configured."
  }
}

# A resource id the caller computes must not decide whether a key exists. A conditional keyed on an
# unknown makes the whole merge unknown, and that hid every policy check on the machine behind an
# unknown `properties` object until it was caught by the resiliency rules.
run "resource_id_inputs_do_not_decide_the_shape_of_the_body" {
  command = apply

  assert {
    condition     = local.windows_vm_body.properties.virtualMachineScaleSet == null
    error_message = "virtual_machine_scale_set_resource_id is routinely computed, so the key must always exist and carry null when unset."
  }
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.osDisk.managedDisk.diskEncryptionSet == null
    error_message = "os_disk.disk_encryption_set_id is routinely computed, so the key must always exist and carry null when unset."
  }
  assert {
    condition     = local.windows_vm_body.properties.storageProfile.osDisk.managedDisk.storageAccountType == "Premium_LRS"
    error_message = "The storage account type must stay readable alongside the computed members, because the resiliency rules read it."
  }
  # Azure assigns the OS disk id for an image build, so carrying it as null would leave AzAPI
  # tracking a path the server fills in and every plan would report drift.
  assert {
    condition     = !can(local.windows_vm_body.properties.storageProfile.osDisk.managedDisk.id)
    error_message = "The OS disk id must only be sent when a disk is being attached."
  }
  # Policy requires this one to be absent rather than null, so it is the deliberate exception.
  assert {
    condition     = !can(local.windows_vm_body.properties.availabilitySet)
    error_message = "availabilitySet must be omitted entirely when unset, because the resiliency rule treats a null as defined."
  }
}

# ARM requires certificateStore on Windows: it names the store to install into. Omitting it fails
# the create with InvalidParameter rather than anything the plan could catch.
run "key_vault_certificates_carry_the_windows_certificate_store" {
  command = apply

  variables {
    secrets = [
      {
        key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
        certificate = [
          {
            url   = "https://kv-test.vault.azure.net/secrets/winrm/0000"
            store = "My"
          }
        ]
      }
    ]
  }

  assert {
    condition     = local.windows_vm_body.properties.osProfile.secrets[0].vaultCertificates[0].certificateStore == "My"
    error_message = "certificateStore is required on Windows, and ARM rejects the create without it."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.secrets[0].vaultCertificates[0].certificateUrl == "https://kv-test.vault.azure.net/secrets/winrm/0000"
    error_message = "The certificate url must be carried alongside the store."
  }
  assert {
    condition     = local.windows_vm_body.properties.osProfile.secrets[0].sourceVault.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
    error_message = "ARM nests the certificates under their source vault."
  }
}

run "immutable_properties_force_replacement" {
  command = apply

  assert {
    condition     = contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.osProfile.adminUsername")
    error_message = "admin_username is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "zones")
    error_message = "zone is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = !contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.osProfile.windowsConfiguration.patchSettings")
    error_message = "The patch settings are updatable in place and must not force replacement."
  }
}

# A body path may only be watched when the module always sends a real value for it. A path the
# module can omit, or send as null to keep the shape of the body readable, differs from the body a
# moved block adopts from Azure, and watching it replaces an adopted machine. Windows has four
# such paths of its own on top of the shared ones.
run "omittable_paths_are_watched_through_their_inputs" {
  command = apply

  variables {
    timezone           = "Pacific Standard Time"
    provision_vm_agent = true
    winrm_listeners    = [{ protocol = "Http" }]
  }

  assert {
    condition     = !contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.osProfile.windowsConfiguration.timeZone")
    error_message = "timeZone is omitted when no timezone is supplied, so watching the body path would replace an adopted machine."
  }
  assert {
    condition     = !contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.osProfile.windowsConfiguration.winRM")
    error_message = "winRM is omitted when no listener is supplied, so watching the body path would replace an adopted machine."
  }
  assert {
    condition     = !contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.osProfile.windowsConfiguration.additionalUnattendContent")
    error_message = "additionalUnattendContent is omitted when no unattend file is supplied, so watching the body path would replace an adopted machine."
  }
  assert {
    condition     = !contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.imageReference")
    error_message = "The image reference is sent as null in attach mode, so watching the body path would replace an adopted machine."
  }
  # They are still ForceNew, they are simply watched through the inputs instead.
  assert {
    condition     = contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_external_values, "Pacific Standard Time")
    error_message = "timezone is ForceNew under azurerm and must still replace the machine when it changes."
  }
  assert {
    condition     = contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_external_values, jsonencode(local.windows_vm_winrm_listeners))
    error_message = "winrm_listeners is ForceNew under azurerm and must still replace the machine when it changes."
  }
}

# Azure fills in the OS disk name and its resource id, so both are present in the body a moved
# block adopts but absent from the body this module sends. Watching the body paths would read that
# as an immutable change and replace an adopted machine.
run "server_assigned_os_disk_values_do_not_force_replacement" {
  command = apply

  assert {
    condition     = !contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.osDisk.name")
    error_message = "Azure names the OS disk when the input is null, so the body path must not be a replacement trigger."
  }
  assert {
    condition     = !contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_refs, "properties.storageProfile.osDisk.managedDisk.id")
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
    condition     = contains(azapi_resource.this_windows_virtual_machine[0].replace_triggers_external_values, "osdisk-explicit")
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
    condition     = local.windows_virtual_machine_output_map.id == azapi_resource.this_windows_virtual_machine[0].id
    error_message = "The compatibility output must expose the virtual machine resource id."
  }
  assert {
    condition     = local.windows_virtual_machine_output_map.virtual_machine_id == "33333333-3333-3333-3333-333333333333"
    error_message = "virtual_machine_id must come from the ARM vmId, which azurerm exposed under that name."
  }
  assert {
    condition     = local.windows_virtual_machine_output_map.identity[0].principal_id == "11111111-1111-1111-1111-111111111111"
    error_message = "azurerm exposed identity as a single element list, so the shape must be preserved."
  }
}
