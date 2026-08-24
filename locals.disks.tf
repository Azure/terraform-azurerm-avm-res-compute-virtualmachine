locals {
  # Each disk may override the resource group; the subscription is resolved once in
  # locals.parent.tf. A null value is left in place so the resource precondition reports it.
  data_disk_parent_ids = {
    for dk, dv in var.data_disk_managed_disks :
    dk => dv.resource_group_name == null && var.parent_id != null ? var.parent_id : (
      local.parent_id_for_resource_group[coalesce(dv.resource_group_name, var.resource_group_name)]
    )
  }

  # ARM groups everything that describes how the disk came into existence under creationData, and
  # rejects members that do not apply to the chosen createOption, so each is omitted when null
  # rather than sent explicitly.
  data_disk_creation_data = {
    for dk, dv in var.data_disk_managed_disks :
    dk => merge(
      { createOption = dv.create_option },
      dv.storage_account_resource_id == null ? {} : { storageAccountId = dv.storage_account_resource_id },
      dv.image_reference_resource_id == null ? {} : { imageReference = { id = dv.image_reference_resource_id } },
      dv.gallery_image_reference_resource_id == null ? {} : { galleryImageReference = { id = dv.gallery_image_reference_resource_id } },
      dv.source_uri == null ? {} : { sourceUri = dv.source_uri },
      dv.source_resource_id == null ? {} : { sourceResourceId = dv.source_resource_id },
      dv.upload_size_bytes == null ? {} : { uploadSizeBytes = dv.upload_size_bytes },
      dv.logical_sector_size == null ? {} : { logicalSectorSize = dv.logical_sector_size },
      dv.performance_plus_enabled ? { performancePlus = true } : {},
    )
  }

  # `trusted_launch_enabled` and `security_type` are separate inputs in the azurerm schema but a
  # single ARM enum. They are mutually exclusive, which a precondition enforces.
  data_disk_security_profile = {
    for dk, dv in var.data_disk_managed_disks :
    dk => dv.security_type == null && dv.trusted_launch_enabled != true ? null : merge(
      { securityType = dv.security_type != null ? dv.security_type : "TrustedLaunch" },
      dv.secure_vm_disk_encryption_set_resource_id == null ? {} : {
        secureVMDiskEncryptionSetId = dv.secure_vm_disk_encryption_set_resource_id
      },
    )
  }

  # The azurerm `encryption_settings` block is a list, but ARM models it as a collection carrying
  # its own `enabled` flag. An empty list means encryption settings are not managed at all.
  data_disk_encryption_settings = {
    for dk, dv in var.data_disk_managed_disks :
    dk => length(dv.encryption_settings) == 0 ? null : {
      enabled = true
      encryptionSettings = [
        for setting in dv.encryption_settings : merge(
          setting.disk_encryption_key_vault_secret_url == null && setting.disk_encryption_key_vault_resource_id == null ? {} : {
            diskEncryptionKey = {
              secretUrl   = setting.disk_encryption_key_vault_secret_url
              sourceVault = { id = setting.disk_encryption_key_vault_resource_id }
            }
          },
          setting.key_encryption_key_vault_secret_url == null && setting.key_encryption_key_vault_resource_id == null ? {} : {
            keyEncryptionKey = {
              keyUrl      = setting.key_encryption_key_vault_secret_url
              sourceVault = { id = setting.key_encryption_key_vault_resource_id }
            }
          },
        )
      ]
    }
  }

  data_disk_bodies = {
    for dk, dv in var.data_disk_managed_disks :
    dk => merge(
      {
        # `sku.tier` is read-only in ARM; the azurerm `tier` input is the performance tier and
        # belongs under properties.
        sku = { name = dv.storage_account_type }
        properties = merge(
          {
            creationData = local.data_disk_creation_data[dk]
            diskSizeGB   = dv.disk_size_gb
          },
          dv.os_type == null ? {} : { osType = dv.os_type },
          dv.hyper_v_generation == null ? {} : { hyperVGeneration = dv.hyper_v_generation },
          dv.disk_iops_read_write == null ? {} : { diskIOPSReadWrite = dv.disk_iops_read_write },
          dv.disk_mbps_read_write == null ? {} : { diskMBpsReadWrite = dv.disk_mbps_read_write },
          dv.disk_iops_read_only == null ? {} : { diskIOPSReadOnly = dv.disk_iops_read_only },
          dv.disk_mbps_read_only == null ? {} : { diskMBpsReadOnly = dv.disk_mbps_read_only },
          dv.disk_encryption_set_resource_id == null ? {} : { encryption = { diskEncryptionSetId = dv.disk_encryption_set_resource_id } },
          dv.max_shares == null ? {} : { maxShares = dv.max_shares },
          dv.network_access_policy == null ? {} : { networkAccessPolicy = dv.network_access_policy },
          dv.disk_access_resource_id == null ? {} : { diskAccessId = dv.disk_access_resource_id },
          dv.tier == null ? {} : { tier = dv.tier },
          dv.on_demand_bursting_enabled == null ? {} : { burstingEnabled = dv.on_demand_bursting_enabled },
          dv.public_network_access_enabled == null ? {} : {
            publicNetworkAccess = dv.public_network_access_enabled ? "Enabled" : "Disabled"
          },
          dv.optimized_frequent_attach_enabled ? { optimizedForFrequentAttach = true } : {},
          local.data_disk_security_profile[dk] == null ? {} : { securityProfile = local.data_disk_security_profile[dk] },
          local.data_disk_encryption_settings[dk] == null ? {} : {
            encryptionSettingsCollection = local.data_disk_encryption_settings[dk]
          },
        )
      },
      # A zonal disk cannot be requested for a zone-redundant storage type, matching the previous
      # implementation's behaviour.
      strcontains(dv.storage_account_type, "ZRS") || var.zone == null ? {} : { zones = [tostring(var.zone)] },
      var.edge_zone == null ? {} : { extendedLocation = { name = var.edge_zone, type = "EdgeZone" } },
    )
  }
}

# D2: the AzAPI resource exposes the ARM schema, which is not what consumers of this module have
# been reading. This reshapes each disk back into the attribute names the azurerm resource
# exported so existing expressions keep working. The unshaped objects remain available through the
# data_disks_azapi output.
locals {
  data_disks_output = {
    for dk, disk in azapi_resource.this_data_disk : dk => {
      id                                = disk.id
      name                              = disk.name
      location                          = disk.location
      resource_group_name               = coalesce(var.data_disk_managed_disks[dk].resource_group_name, var.resource_group_name)
      tags                              = disk.tags
      storage_account_type              = var.data_disk_managed_disks[dk].storage_account_type
      create_option                     = var.data_disk_managed_disks[dk].create_option
      disk_size_gb                      = var.data_disk_managed_disks[dk].disk_size_gb
      disk_access_id                    = var.data_disk_managed_disks[dk].disk_access_resource_id
      disk_encryption_set_id            = var.data_disk_managed_disks[dk].disk_encryption_set_resource_id
      disk_iops_read_only               = var.data_disk_managed_disks[dk].disk_iops_read_only
      disk_iops_read_write              = var.data_disk_managed_disks[dk].disk_iops_read_write
      disk_mbps_read_only               = var.data_disk_managed_disks[dk].disk_mbps_read_only
      disk_mbps_read_write              = var.data_disk_managed_disks[dk].disk_mbps_read_write
      gallery_image_reference_id        = var.data_disk_managed_disks[dk].gallery_image_reference_resource_id
      hyper_v_generation                = var.data_disk_managed_disks[dk].hyper_v_generation
      image_reference_id                = var.data_disk_managed_disks[dk].image_reference_resource_id
      logical_sector_size               = var.data_disk_managed_disks[dk].logical_sector_size
      max_shares                        = var.data_disk_managed_disks[dk].max_shares
      network_access_policy             = var.data_disk_managed_disks[dk].network_access_policy
      on_demand_bursting_enabled        = var.data_disk_managed_disks[dk].on_demand_bursting_enabled
      optimized_frequent_attach_enabled = var.data_disk_managed_disks[dk].optimized_frequent_attach_enabled
      os_type                           = var.data_disk_managed_disks[dk].os_type
      performance_plus_enabled          = var.data_disk_managed_disks[dk].performance_plus_enabled
      public_network_access_enabled     = var.data_disk_managed_disks[dk].public_network_access_enabled
      secure_vm_disk_encryption_set_id  = var.data_disk_managed_disks[dk].secure_vm_disk_encryption_set_resource_id
      security_type                     = var.data_disk_managed_disks[dk].security_type
      source_resource_id                = var.data_disk_managed_disks[dk].source_resource_id
      source_uri                        = var.data_disk_managed_disks[dk].source_uri
      storage_account_id                = var.data_disk_managed_disks[dk].storage_account_resource_id
      tier                              = var.data_disk_managed_disks[dk].tier
      trusted_launch_enabled            = var.data_disk_managed_disks[dk].trusted_launch_enabled
      upload_size_bytes                 = var.data_disk_managed_disks[dk].upload_size_bytes
      zone                              = strcontains(var.data_disk_managed_disks[dk].storage_account_type, "ZRS") ? null : var.zone
      disk_size_bytes                   = try(disk.output.properties.diskSizeBytes, null)
      unique_id                         = try(disk.output.properties.uniqueId, null)
    }
  }
}
