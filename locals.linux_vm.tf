locals {
  # ARM nests the managed disk settings of the OS disk under storageProfile.osDisk.managedDisk,
  # while the azurerm schema kept them flat on the os_disk block.
  #
  # Every member below is written as an always-present key whose value may be null, rather than as
  # a conditional that decides whether the key exists. A conditional keyed on a value the caller
  # computes is unknown at plan time, and a single unknown argument makes the whole merge unknown,
  # which hides the entire body from policy checks. Only the leaves may be unknown.
  linux_vm_os_disk_managed_disk = merge(
    var.os_disk.storage_account_type == null || var.os_disk_attach_mode ? {} : {
      storageAccountType = var.os_disk.storage_account_type
    },
    {
      diskEncryptionSet = var.os_disk.disk_encryption_set_id == null ? null : { id = var.os_disk.disk_encryption_set_id }
      securityProfile = var.os_disk.secure_vm_disk_encryption_set_id == null && var.os_disk.security_encryption_type == null ? null : merge(
        var.os_disk.security_encryption_type == null ? {} : { securityEncryptionType = var.os_disk.security_encryption_type },
        {
          diskEncryptionSet = var.os_disk.secure_vm_disk_encryption_set_id == null ? null : {
            id = var.os_disk.secure_vm_disk_encryption_set_id
          }
        },
      )
      # Attaching an existing managed disk replaces the image-based create entirely.
      id = var.os_managed_disk_id
    },
  )

  linux_vm_os_disk = merge(
    {
      # Attach reuses an existing disk; every other path creates one from the image.
      createOption = var.os_disk_attach_mode ? "Attach" : "FromImage"
      caching      = var.os_disk.caching
      # The azurerm provider deleted the OS disk itself when the machine was destroyed, through
      # the delete_os_disk_on_deletion feature that defaults to true. AzAPI has no equivalent, so
      # ARM is asked to do it instead. A disk the caller attached stays, because they own it.
      deleteOption = var.os_disk_attach_mode ? "Detach" : "Delete"
    },
    var.os_disk_attach_mode ? { osType = "Linux" } : {},
    var.os_disk.name == null ? {} : { name = var.os_disk.name },
    var.os_disk.disk_size_gb == null ? {} : { diskSizeGB = var.os_disk.disk_size_gb },
    var.os_disk.write_accelerator_enabled == null ? {} : { writeAcceleratorEnabled = var.os_disk.write_accelerator_enabled },
    var.os_disk.diff_disk_settings == null ? {} : {
      diffDiskSettings = {
        option    = var.os_disk.diff_disk_settings.option
        placement = var.os_disk.diff_disk_settings.placement
      }
    },
    { managedDisk = local.linux_vm_os_disk_managed_disk },
  )

  # ARM groups the guest patching inputs under linuxConfiguration.patchSettings. It is only read
  # from inside linuxConfiguration, which is itself dropped in attach mode, so there is no null
  # case here: a null would have to be unified with the object type and break the merge.
  linux_vm_patch_settings = merge(
    var.patch_mode == null ? {} : { patchMode = var.patch_mode },
    var.patch_assessment_mode == null ? {} : { assessmentMode = var.patch_assessment_mode },
    var.patch_mode != "AutomaticByPlatform" ? {} : {
      automaticByPlatformSettings = merge(
        var.reboot_setting == null ? {} : { rebootSetting = var.reboot_setting },
        { bypassPlatformSafetyChecksOnUserSchedule = coalesce(var.bypass_platform_safety_checks_on_user_schedule_enabled, false) },
      )
    },
  )

  # The public half of an SSH key pair is not a secret, so it stays in the ordinary body. The
  # value may be unknown when the module generates the key, but the shape never is.
  linux_vm_ssh_public_keys = [
    for key in local.admin_ssh_keys : {
      keyData = key.public_key
      path    = "/home/${key.username}/.ssh/authorized_keys"
    }
  ]

  linux_vm_linux_configuration = var.os_disk_attach_mode ? null : merge(
    {
      disablePasswordAuthentication = local.password_authentication_disabled
    },
    var.provision_vm_agent == null ? {} : { provisionVMAgent = var.provision_vm_agent },
    length(local.linux_vm_ssh_public_keys) == 0 ? {} : {
      ssh = { publicKeys = local.linux_vm_ssh_public_keys }
    },
    length(local.linux_vm_patch_settings) == 0 ? {} : {
      patchSettings = local.linux_vm_patch_settings
    },
  )

  # Key Vault certificates surfaced to the guest. ARM nests them per source vault.
  linux_vm_os_profile_secrets = [
    for secret in var.secrets : {
      sourceVault = { id = secret.key_vault_id }
      vaultCertificates = [
        for certificate in secret.certificate : { certificateUrl = certificate.url }
      ]
    }
  ]

  # osProfile is rejected outright when attaching an existing OS disk, because the guest is
  # already provisioned.
  linux_vm_os_profile = var.os_disk_attach_mode ? null : merge(
    {
      adminUsername = local.admin_username
      computerName  = coalesce(var.computer_name, var.name)
    },
    var.allow_extension_operations == null ? {} : { allowExtensionOperations = var.allow_extension_operations },
    local.linux_vm_linux_configuration == null ? {} : { linuxConfiguration = local.linux_vm_linux_configuration },
    length(local.linux_vm_os_profile_secrets) == 0 ? {} : { secrets = local.linux_vm_os_profile_secrets },
  )

  # The interface order is significant: ARM marks the first entry primary.
  linux_vm_network_interfaces = [
    for index, key in local.ordered_network_interface_keys : {
      id         = azapi_resource.virtualmachine_network_interfaces[key].id
      properties = { primary = index == 0 }
    }
  ]

  linux_vm_image_reference = var.os_disk_attach_mode ? null : (
    var.source_image_resource_id != null ? { id = var.source_image_resource_id } : {
      publisher                                 = local.source_image_reference.publisher
      offer                                     = local.source_image_reference.offer
      sku                                       = local.source_image_reference.sku
      version                                   = local.source_image_reference.version
    }
  )

  linux_vm_uefi_settings = var.secure_boot_enabled == null && var.vtpm_enabled == null ? null : merge(
    var.secure_boot_enabled == null ? {} : { secureBootEnabled = var.secure_boot_enabled },
    var.vtpm_enabled == null ? {} : { vTpmEnabled = var.vtpm_enabled },
  )

  linux_vm_security_profile = merge(
    var.encryption_at_host_enabled == null ? {} : { encryptionAtHost = var.encryption_at_host_enabled },
    local.linux_vm_uefi_settings == null ? {} : { uefiSettings = local.linux_vm_uefi_settings },
    # ARM requires a security type alongside the UEFI settings. Each conditional yields an object
    # with a single attribute so Terraform can unify it with the empty case.
    local.linux_vm_uefi_settings == null ? {} : {
      securityType = var.os_disk.security_encryption_type != null ? "ConfidentialVM" : "TrustedLaunch"
    },
  )

  linux_vm_gallery_applications = [
    for key, application in var.gallery_applications : merge(
      {
        packageReferenceId     = application.version_id
        configurationReference = application.configuration_blob_uri
      },
      application.order == null ? {} : { order = application.order },
      application.tag == null ? {} : { tags = application.tag },
    )
  ]

  linux_vm_body = merge(
    {
      properties = merge(
        {
          hardwareProfile = { vmSize = var.sku_size }
          storageProfile = merge(
            { osDisk = local.linux_vm_os_disk },
            { imageReference = local.linux_vm_image_reference },
            var.disk_controller_type == null ? {} : { diskControllerType = var.disk_controller_type },
          )
          networkProfile = { networkInterfaces = local.linux_vm_network_interfaces }
        },
        local.linux_vm_os_profile == null ? {} : { osProfile = local.linux_vm_os_profile },
        length(local.linux_vm_security_profile) == 0 ? {} : { securityProfile = local.linux_vm_security_profile },
        var.boot_diagnostics ? {
          diagnosticsProfile = {
            bootDiagnostics = {
              enabled    = true
              storageUri = var.boot_diagnostics_storage_account_uri
            }
          }
        } : {},
        var.vm_additional_capabilities == null ? {} : {
          additionalCapabilities = merge(
            var.vm_additional_capabilities.hibernation_enabled == null ? {} : { hibernationEnabled = var.vm_additional_capabilities.hibernation_enabled },
            var.vm_additional_capabilities.ultra_ssd_enabled == null ? {} : { ultraSSDEnabled = var.vm_additional_capabilities.ultra_ssd_enabled },
          )
        },
        # Each of these is a resource id the caller routinely computes, so the key is always
        # present and only the value varies. Deciding key presence on an unknown would make the
        # whole properties object unknown and blind every policy check on the machine.
        {
          capacityReservation     = var.capacity_reservation_group_resource_id == null ? null : { capacityReservationGroup = { id = var.capacity_reservation_group_resource_id } }
          host                    = var.dedicated_host_resource_id == null ? null : { id = var.dedicated_host_resource_id }
          hostGroup               = var.dedicated_host_group_resource_id == null ? null : { id = var.dedicated_host_group_resource_id }
          proximityPlacementGroup = var.proximity_placement_group_resource_id == null ? null : { id = var.proximity_placement_group_resource_id }
          virtualMachineScaleSet  = var.virtual_machine_scale_set_resource_id == null ? null : { id = var.virtual_machine_scale_set_resource_id }
          userData                = var.user_data
        },
        # availabilitySet is the exception to the rule above. Policy requires the property to be
        # absent rather than null, so the key has to stay conditional. That is safe here: the
        # condition is only unknown when the caller actually supplies an availability set, and a
        # machine that does cannot satisfy the rule anyway.
        var.availability_set_resource_id == null ? {} : { availabilitySet = { id = var.availability_set_resource_id } },
        var.priority == null ? {} : { priority = var.priority },
        var.eviction_policy == null ? {} : { evictionPolicy = var.eviction_policy },
        var.max_bid_price == null || var.max_bid_price == -1 ? {} : { billingProfile = { maxPrice = var.max_bid_price } },
        var.license_type == null ? {} : { licenseType = var.license_type },
        var.extensions_time_budget == null ? {} : { extensionsTimeBudget = var.extensions_time_budget },
        var.platform_fault_domain == null || var.platform_fault_domain == -1 ? {} : { platformFaultDomain = var.platform_fault_domain },
        length(local.linux_vm_gallery_applications) == 0 ? {} : {
          applicationProfile = { galleryApplications = local.linux_vm_gallery_applications }
        },
        var.termination_notification == null ? {} : {
          scheduledEventsProfile = {
            terminateNotificationProfile = {
              enable           = var.termination_notification.enabled
              notBeforeTimeout = var.termination_notification.timeout
            }
          }
        },
      )
    },
    local.managed_identity_type == null ? {} : {
      identity = merge(
        { type = local.managed_identity_type },
        length(var.managed_identities.user_assigned_resource_ids) == 0 ? {} : {
          userAssignedIdentities = {
            for id in var.managed_identities.user_assigned_resource_ids : id => {}
          }
        },
      )
    },
    var.plan == null ? {} : {
      plan = {
        name      = var.plan.name
        product   = var.plan.product
        publisher = var.plan.publisher
      }
    },
    # Only var.zone decides the value, never the shape. See locals.disks.tf for why an unknown
    # condition would make the whole body unknown at plan time.
    { zones = var.zone == null ? [] : [tostring(var.zone)] },
    var.edge_zone == null ? {} : { extendedLocation = { name = var.edge_zone, type = "EdgeZone" } },
  )

  # Secrets are kept out of `body` so they are never written to state or shown in a plan. The
  # attribute is write-only, which requires Terraform 1.11, so it is only populated when a secret
  # is actually supplied. Consumers using SSH keys and no custom data are unaffected.
  # Built as one osProfile object because merge is shallow: merging two objects that each nest
  # properties.osProfile would discard the first.
  linux_vm_sensitive_os_profile = merge(
    local.admin_password_linux == null ? {} : { adminPassword = local.admin_password_linux },
    var.custom_data == null ? {} : { customData = var.custom_data },
  )
  linux_vm_sensitive_body = length(local.linux_vm_sensitive_os_profile) == 0 ? null : {
    properties = { osProfile = local.linux_vm_sensitive_os_profile }
  }

  # Both values are ForceNew under the azurerm provider, and ARM cannot change either in place.
  # Hashing keeps the replacement trigger working without putting the secret itself into state.
  linux_vm_secret_fingerprint = length(local.linux_vm_sensitive_os_profile) == 0 ? null : sha256(join("|", [
    local.admin_password_linux == null ? "" : local.admin_password_linux,
    var.custom_data == null ? "" : var.custom_data,
  ]))
}
