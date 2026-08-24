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
  # The data disk attachment parses the virtual machine ID, so the mocked machine needs a
  # well-formed ARM ID rather than the generated placeholder.
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-disks"
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-disks-osdisk"
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}
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
variables {
  location            = "eastus"
  name                = "vm-disks"
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
  data_disk_managed_disks = {
    disk1 = {
      caching              = "ReadWrite"
      lun                  = 0
      name                 = "disk-test"
      storage_account_type = "Premium_LRS"
    }
  }
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

run "disk_defaults_are_mapped_to_arm_names" {
  command = apply

  assert {
    condition     = local.data_disk_bodies["disk1"].sku.name == "Premium_LRS"
    error_message = "storage_account_type must map to sku.name."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.creationData.createOption == "Empty"
    error_message = "create_option must map to properties.creationData.createOption."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.diskSizeGB == 128
    error_message = "disk_size_gb must map to properties.diskSizeGB."
  }
  assert {
    condition     = azapi_resource.this_data_disk["disk1"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    error_message = "The disk must be created in resource_group_name using the derived subscription."
  }
  assert {
    condition     = azapi_resource.this_data_disk["disk1"].type == "Microsoft.Compute/disks@2024-03-02"
    error_message = "The disk must use the compute_disks resource type."
  }
}

run "a_zonal_disk_requests_the_configured_zone" {
  command = apply

  assert {
    condition     = one(local.data_disk_bodies["disk1"].zones) == "1"
    error_message = "A non-ZRS disk must request the module's zone as an ARM zones list."
  }
}

run "a_zone_redundant_disk_omits_zones" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching              = "ReadWrite"
        lun                  = 0
        name                 = "disk-test"
        storage_account_type = "Premium_ZRS"
      }
    }
  }

  assert {
    condition     = !can(local.data_disk_bodies["disk1"].zones)
    error_message = "A zone-redundant disk must not request a zone."
  }
}

run "omitted_optional_properties_are_absent_from_the_body" {
  command = apply

  assert {
    condition     = !can(local.data_disk_bodies["disk1"].properties.securityProfile)
    error_message = "securityProfile must be omitted when neither security_type nor trusted_launch_enabled is set."
  }
  assert {
    condition     = !can(local.data_disk_bodies["disk1"].properties.encryptionSettingsCollection)
    error_message = "encryptionSettingsCollection must be omitted when no encryption settings are supplied."
  }
  assert {
    condition     = !can(local.data_disk_bodies["disk1"].properties.tier)
    error_message = "tier must be omitted when not supplied, rather than sent as null."
  }
  assert {
    condition     = !can(local.data_disk_bodies["disk1"].properties.creationData.sourceResourceId)
    error_message = "creationData members that do not apply to the create option must be omitted."
  }
}

run "the_performance_tier_is_not_sent_as_a_sku_tier" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching              = "ReadWrite"
        lun                  = 0
        name                 = "disk-test"
        storage_account_type = "Premium_LRS"
        tier                 = "P30"
      }
    }
  }

  assert {
    condition     = local.data_disk_bodies["disk1"].properties.tier == "P30"
    error_message = "The performance tier belongs under properties.tier."
  }
  assert {
    condition     = !can(local.data_disk_bodies["disk1"].sku.tier)
    error_message = "sku.tier is read-only in ARM and must never be sent."
  }
}

run "copy_source_and_network_access_are_mapped" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching                       = "ReadWrite"
        lun                           = 0
        name                          = "disk-test"
        storage_account_type          = "Premium_LRS"
        create_option                 = "Copy"
        source_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/snapshots/snap-test"
        network_access_policy         = "AllowPrivate"
        disk_access_resource_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/diskAccesses/da-test"
        public_network_access_enabled = false
        max_shares                    = 2
        on_demand_bursting_enabled    = true
      }
    }
  }

  assert {
    condition     = local.data_disk_bodies["disk1"].properties.creationData.sourceResourceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/snapshots/snap-test"
    error_message = "source_resource_id must map into creationData."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.publicNetworkAccess == "Disabled"
    error_message = "public_network_access_enabled must map to the publicNetworkAccess enum."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.networkAccessPolicy == "AllowPrivate"
    error_message = "network_access_policy must map to properties.networkAccessPolicy."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.diskAccessId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/diskAccesses/da-test"
    error_message = "disk_access_resource_id must map to properties.diskAccessId."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.burstingEnabled == true
    error_message = "on_demand_bursting_enabled must map to properties.burstingEnabled."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.maxShares == 2
    error_message = "max_shares must map to properties.maxShares."
  }
}

run "trusted_launch_collapses_into_the_arm_security_type" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching                = "ReadWrite"
        lun                    = 0
        name                   = "disk-test"
        storage_account_type   = "Premium_LRS"
        trusted_launch_enabled = true
      }
    }
  }

  assert {
    condition     = local.data_disk_bodies["disk1"].properties.securityProfile.securityType == "TrustedLaunch"
    error_message = "trusted_launch_enabled must map to a securityType of TrustedLaunch."
  }
}

run "an_explicit_security_type_is_used_verbatim" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching              = "ReadWrite"
        lun                  = 0
        name                 = "disk-test"
        storage_account_type = "Premium_LRS"
        security_type        = "ConfidentialVM_DiskEncryptedWithPlatformKey"
      }
    }
  }

  assert {
    condition     = local.data_disk_bodies["disk1"].properties.securityProfile.securityType == "ConfidentialVM_DiskEncryptedWithPlatformKey"
    error_message = "A supplied security_type must be carried through unchanged."
  }
}

run "security_type_and_trusted_launch_together_are_rejected" {
  command = plan

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching                = "ReadWrite"
        lun                    = 0
        name                   = "disk-test"
        storage_account_type   = "Premium_LRS"
        trusted_launch_enabled = true
        security_type          = "ConfidentialVM_DiskEncryptedWithPlatformKey"
      }
    }
  }

  expect_failures = [azapi_resource.this_data_disk]
}

run "encryption_settings_become_an_arm_collection" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching              = "ReadWrite"
        lun                  = 0
        name                 = "disk-test"
        storage_account_type = "Premium_LRS"
        encryption_settings = [{
          disk_encryption_key_vault_secret_url  = "https://kv-test.vault.azure.net/secrets/secret/version"
          disk_encryption_key_vault_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
          key_encryption_key_vault_secret_url   = "https://kv-test.vault.azure.net/keys/key/version"
          key_encryption_key_vault_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
        }]
      }
    }
  }

  assert {
    condition     = local.data_disk_bodies["disk1"].properties.encryptionSettingsCollection.enabled == true
    error_message = "Supplying encryption settings must enable the ARM collection."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.encryptionSettingsCollection.encryptionSettings[0].diskEncryptionKey.secretUrl == "https://kv-test.vault.azure.net/secrets/secret/version"
    error_message = "The disk encryption key secret URL must be carried into the collection."
  }
  assert {
    condition     = local.data_disk_bodies["disk1"].properties.encryptionSettingsCollection.encryptionSettings[0].keyEncryptionKey.sourceVault.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
    error_message = "The key encryption key vault must be carried into the collection."
  }
}

run "immutable_properties_force_replacement" {
  command = apply

  assert {
    condition     = contains(azapi_resource.this_data_disk["disk1"].replace_triggers_refs, "properties.creationData.createOption")
    error_message = "create_option is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = contains(azapi_resource.this_data_disk["disk1"].replace_triggers_refs, "properties.creationData.sourceResourceId")
    error_message = "source_resource_id is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = contains(azapi_resource.this_data_disk["disk1"].replace_triggers_refs, "properties.hyperVGeneration")
    error_message = "hyper_v_generation is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = contains(azapi_resource.this_data_disk["disk1"].replace_triggers_refs, "properties.securityProfile.securityType")
    error_message = "security_type is ForceNew under azurerm and must trigger replacement under AzAPI."
  }
  assert {
    condition     = !contains(azapi_resource.this_data_disk["disk1"].replace_triggers_refs, "properties.diskSizeGB")
    error_message = "disk_size_gb is resizable and must not force replacement."
  }
  assert {
    condition     = !contains(azapi_resource.this_data_disk["disk1"].replace_triggers_refs, "properties.tier")
    error_message = "The performance tier is updatable and must not force replacement."
  }
}

run "a_per_disk_resource_group_overrides_the_parent" {
  command = apply

  variables {
    data_disk_managed_disks = {
      disk1 = {
        caching              = "ReadWrite"
        lun                  = 0
        name                 = "disk-test"
        storage_account_type = "Premium_LRS"
        resource_group_name  = "rg-disks"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_data_disk["disk1"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-disks"
    error_message = "A per-disk resource_group_name must replace the resource group while keeping the derived subscription."
  }
}

run "the_data_disks_output_keeps_the_azurerm_shape" {
  command = apply

  assert {
    condition     = local.data_disks_output["disk1"].storage_account_type == "Premium_LRS"
    error_message = "The shimmed output must expose storage_account_type as the azurerm resource did."
  }
  assert {
    condition     = local.data_disks_output["disk1"].resource_group_name == "rg-test"
    error_message = "The shimmed output must expose the resolved resource group name."
  }
  assert {
    condition     = local.data_disks_output["disk1"].zone == "1"
    error_message = "The shimmed output must expose the disk's zone."
  }
  assert {
    condition     = local.data_disks_output["disk1"].id == azapi_resource.this_data_disk["disk1"].id
    error_message = "The shimmed output must expose the disk resource ID."
  }
}
