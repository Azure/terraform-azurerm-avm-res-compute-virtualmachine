locals {
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

  # osProfile is rejected outright when attaching an existing OS disk, because the guest is
  # already provisioned.
  linux_vm_os_profile = var.os_disk_attach_mode ? null : merge(
    {
      adminUsername = local.admin_username
      computerName  = coalesce(var.computer_name, var.name)
    },
    var.allow_extension_operations == null ? {} : { allowExtensionOperations = var.allow_extension_operations },
    local.linux_vm_linux_configuration == null ? {} : { linuxConfiguration = local.linux_vm_linux_configuration },
    length(local.vm_os_profile_secrets) == 0 ? {} : { secrets = local.vm_os_profile_secrets },
  )

  linux_vm_body = merge(
    {
      properties = merge(
        local.vm_common_properties,
        local.linux_vm_os_profile == null ? {} : { osProfile = local.linux_vm_os_profile },
      )
    },
    local.vm_common_top_level,
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
