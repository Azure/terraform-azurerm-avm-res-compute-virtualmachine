locals {
  # Everything below is identical for Linux and Windows. Only osProfile differs between them, so
  # the two virtual machine bodies compose these shared pieces rather than repeating them.
  #
  # Members whose value the caller routinely computes are written as an always-present key whose
  # value may be null, rather than as a conditional that decides whether the key exists. A
  # conditional keyed on a computed value is unknown at plan time, and a single unknown argument
  # makes the whole merge unknown, which hides the entire body from policy checks. Only the leaves
  # may be unknown.
  vm_os_disk_managed_disk = merge(
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
    },
    # Attaching an existing managed disk replaces the image-based create entirely. Azure assigns
    # this id itself for an image build, so sending it as null there would leave AzAPI tracking a
    # path the server always fills in, and every plan would report drift. os_disk_attach_mode is a
    # plain input rather than a computed value, so keying the presence on it is known at plan time.
    var.os_disk_attach_mode ? { id = var.os_managed_disk_id } : {},
  )

  vm_os_disk = merge(
    {
      # Attach reuses an existing disk; every other path creates one from the image.
      createOption = var.os_disk_attach_mode ? "Attach" : "FromImage"
      caching      = var.os_disk.caching
      # The azurerm provider deleted the OS disk itself when the machine was destroyed, through
      # the delete_os_disk_on_deletion feature that defaults to true. AzAPI has no equivalent, so
      # ARM is asked to do it instead. A disk the caller attached stays, because they own it.
      deleteOption = var.os_disk_attach_mode ? "Detach" : "Delete"
    },
    var.os_disk_attach_mode ? { osType = lower(var.os_type) == "windows" ? "Windows" : "Linux" } : {},
    var.os_disk.name == null ? {} : { name = var.os_disk.name },
    var.os_disk.disk_size_gb == null ? {} : { diskSizeGB = var.os_disk.disk_size_gb },
    var.os_disk.write_accelerator_enabled == null ? {} : { writeAcceleratorEnabled = var.os_disk.write_accelerator_enabled },
    var.os_disk.diff_disk_settings == null ? {} : {
      diffDiskSettings = {
        option    = var.os_disk.diff_disk_settings.option
        placement = var.os_disk.diff_disk_settings.placement
      }
    },
    { managedDisk = local.vm_os_disk_managed_disk },
  )

  # The interface order is significant: ARM marks the first entry primary.
  vm_network_interfaces = [
    for index, key in local.ordered_network_interface_keys : {
      id         = azapi_resource.virtualmachine_network_interfaces[key].id
      properties = { primary = index == 0 }
    }
  ]

  vm_image_reference = var.os_disk_attach_mode ? null : (
    var.source_image_resource_id != null ? { id = var.source_image_resource_id } : {
      publisher                                 = local.source_image_reference.publisher
      offer                                     = local.source_image_reference.offer
      sku                                       = local.source_image_reference.sku
      version                                   = local.source_image_reference.version
    }
  )

  vm_uefi_settings = var.secure_boot_enabled == null && var.vtpm_enabled == null ? null : merge(
    var.secure_boot_enabled == null ? {} : { secureBootEnabled = var.secure_boot_enabled },
    var.vtpm_enabled == null ? {} : { vTpmEnabled = var.vtpm_enabled },
  )

  vm_security_profile = merge(
    var.encryption_at_host_enabled == null ? {} : { encryptionAtHost = var.encryption_at_host_enabled },
    local.vm_uefi_settings == null ? {} : { uefiSettings = local.vm_uefi_settings },
    # ARM requires a security type alongside the UEFI settings. Each conditional yields an object
    # with a single attribute so Terraform can unify it with the empty case.
    local.vm_uefi_settings == null ? {} : {
      securityType = var.os_disk.security_encryption_type != null ? "ConfidentialVM" : "TrustedLaunch"
    },
  )

  vm_gallery_applications = [
    for key, application in var.gallery_applications : merge(
      {
        packageReferenceId     = application.version_id
        configurationReference = application.configuration_blob_uri
      },
      application.order == null ? {} : { order = application.order },
      application.tag == null ? {} : { tags = application.tag },
    )
  ]

  # Key Vault certificates surfaced to the guest. ARM nests them per source vault.
  #
  # certificateStore names the Windows certificate store to install into and is required there.
  # Linux has no equivalent: the certificate is written to a file, and the azurerm provider did not
  # expose the field on the Linux machine at all. os_type is a plain input, so keying the presence
  # on it is known at plan time and cannot collapse the shape of the body.
  vm_os_profile_secrets = [
    for secret in var.secrets : {
      sourceVault = { id = secret.key_vault_id }
      vaultCertificates = [
        for certificate in secret.certificate : merge(
          { certificateUrl = certificate.url },
          lower(var.os_type) == "windows" ? { certificateStore = certificate.store } : {},
        )
      ]
    }
  ]

  # Everything under `properties` that does not depend on the guest operating system. Each virtual
  # machine merges its own osProfile into this.
  vm_common_properties = merge(
    {
      hardwareProfile = { vmSize = var.sku_size }
      storageProfile = merge(
        { osDisk = local.vm_os_disk },
        { imageReference = local.vm_image_reference },
        var.disk_controller_type == null ? {} : { diskControllerType = var.disk_controller_type },
      )
      networkProfile = { networkInterfaces = local.vm_network_interfaces }
    },
    length(local.vm_security_profile) == 0 ? {} : { securityProfile = local.vm_security_profile },
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
    # Each of these is a resource id the caller routinely computes, so the key is always present
    # and only the value varies. Deciding key presence on an unknown would make the whole
    # properties object unknown and blind every policy check on the machine.
    {
      capacityReservation     = var.capacity_reservation_group_resource_id == null ? null : { capacityReservationGroup = { id = var.capacity_reservation_group_resource_id } }
      host                    = var.dedicated_host_resource_id == null ? null : { id = var.dedicated_host_resource_id }
      hostGroup               = var.dedicated_host_group_resource_id == null ? null : { id = var.dedicated_host_group_resource_id }
      proximityPlacementGroup = var.proximity_placement_group_resource_id == null ? null : { id = var.proximity_placement_group_resource_id }
      virtualMachineScaleSet  = var.virtual_machine_scale_set_resource_id == null ? null : { id = var.virtual_machine_scale_set_resource_id }
      userData                = var.user_data
    },
    # availabilitySet is the exception to the rule above. Policy requires the property to be absent
    # rather than null, so the key has to stay conditional. That is safe here: the condition is
    # only unknown when the caller actually supplies an availability set, and a machine that does
    # cannot satisfy the rule anyway.
    var.availability_set_resource_id == null ? {} : { availabilitySet = { id = var.availability_set_resource_id } },
    var.priority == null ? {} : { priority = var.priority },
    var.eviction_policy == null ? {} : { evictionPolicy = var.eviction_policy },
    var.max_bid_price == null || var.max_bid_price == -1 ? {} : { billingProfile = { maxPrice = var.max_bid_price } },
    var.license_type == null ? {} : { licenseType = var.license_type },
    var.extensions_time_budget == null ? {} : { extensionsTimeBudget = var.extensions_time_budget },
    var.platform_fault_domain == null || var.platform_fault_domain == -1 ? {} : { platformFaultDomain = var.platform_fault_domain },
    length(local.vm_gallery_applications) == 0 ? {} : {
      applicationProfile = { galleryApplications = local.vm_gallery_applications }
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

  # Body members that sit outside `properties`.
  vm_common_top_level = merge(
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
    # Only var.zone decides the value, never the shape. A condition keyed on a computed value
    # would make the whole body unknown at plan time and hide every field from policy checks.
    { zones = var.zone == null ? [] : [tostring(var.zone)] },
    var.edge_zone == null ? {} : { extendedLocation = { name = var.edge_zone, type = "EdgeZone" } },
  )
}
