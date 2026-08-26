locals {
  # ARM groups the guest patching inputs under windowsConfiguration.patchSettings. Hotpatching is
  # a Windows-only member of the same object. It is only read from inside windowsConfiguration,
  # which is itself dropped in attach mode, so there is no null case here: a null would have to be
  # unified with the object type and break the merge.
  windows_vm_patch_settings = merge(
    var.patch_mode == null ? {} : { patchMode = var.patch_mode },
    var.patch_assessment_mode == null ? {} : { assessmentMode = var.patch_assessment_mode },
    var.hotpatching_enabled == null ? {} : { enableHotpatching = var.hotpatching_enabled },
    var.patch_mode != "AutomaticByPlatform" ? {} : {
      automaticByPlatformSettings = merge(
        var.reboot_setting == null ? {} : { rebootSetting = var.reboot_setting },
        { bypassPlatformSafetyChecksOnUserSchedule = coalesce(var.bypass_platform_safety_checks_on_user_schedule_enabled, false) },
      )
    },
  )

  # The azurerm provider fixed the pass and component, exposing only the setting name and content.
  # Those are the only values Azure accepts for an unattend file, so they stay fixed here too.
  windows_vm_additional_unattend_content = [
    for content in var.additional_unattend_contents : {
      passName      = "OobeSystem"
      componentName = "Microsoft-Windows-Shell-Setup"
      settingName   = content.setting
    }
  ]

  windows_vm_winrm_listeners = [
    for listener in var.winrm_listeners : merge(
      { protocol = listener.protocol },
      listener.certificate_url == null ? {} : { certificateUrl = listener.certificate_url },
    )
  ]

  windows_vm_windows_configuration = var.os_disk_attach_mode ? null : merge(
    var.provision_vm_agent == null ? {} : { provisionVMAgent = var.provision_vm_agent },
    # The deprecated enable_automatic_updates input still feeds this, and both inputs resolve to a
    # value, so the key is always present.
    { enableAutomaticUpdates = local.automatic_updates_enabled },
    var.timezone == null ? {} : { timeZone = var.timezone },
    length(local.windows_vm_winrm_listeners) == 0 ? {} : {
      winRM = { listeners = local.windows_vm_winrm_listeners }
    },
    # The content of an unattend file routinely carries credentials, so only its shape is declared
    # here. The content itself is supplied through sensitive_body.
    length(local.windows_vm_additional_unattend_content) == 0 ? {} : {
      additionalUnattendContent = local.windows_vm_additional_unattend_content
    },
    length(local.windows_vm_patch_settings) == 0 ? {} : {
      patchSettings = local.windows_vm_patch_settings
    },
  )

  # osProfile is rejected outright when attaching an existing OS disk, because the guest is
  # already provisioned.
  windows_vm_os_profile = var.os_disk_attach_mode ? null : merge(
    {
      adminUsername = local.admin_username
      computerName  = coalesce(var.computer_name, var.name)
    },
    var.allow_extension_operations == null ? {} : { allowExtensionOperations = var.allow_extension_operations },
    local.windows_vm_windows_configuration == null ? {} : { windowsConfiguration = local.windows_vm_windows_configuration },
    length(local.vm_os_profile_secrets) == 0 ? {} : { secrets = local.vm_os_profile_secrets },
  )

  windows_vm_body = merge(
    {
      properties = merge(
        local.vm_common_properties,
        local.windows_vm_os_profile == null ? {} : { osProfile = local.windows_vm_os_profile },
      )
    },
    local.vm_common_top_level,
  )

  # A Windows machine always authenticates with a password, so unlike Linux the sensitive body is
  # populated on every deployment that is not attaching an existing OS disk. Built as one
  # osProfile object because merge is shallow.
  windows_vm_sensitive_unattend_content = [
    for index, content in var.additional_unattend_contents : {
      passName      = "OobeSystem"
      componentName = "Microsoft-Windows-Shell-Setup"
      settingName   = content.setting
      content       = content.content
    }
  ]

  windows_vm_sensitive_windows_configuration = length(local.windows_vm_sensitive_unattend_content) == 0 ? {} : {
    windowsConfiguration = { additionalUnattendContent = local.windows_vm_sensitive_unattend_content }
  }

  windows_vm_sensitive_os_profile = merge(
    local.admin_password_windows == null ? {} : { adminPassword = local.admin_password_windows },
    var.custom_data == null ? {} : { customData = var.custom_data },
    local.windows_vm_sensitive_windows_configuration,
  )
  windows_vm_sensitive_body = length(local.windows_vm_sensitive_os_profile) == 0 ? null : {
    properties = { osProfile = local.windows_vm_sensitive_os_profile }
  }

  # All three values are ForceNew under the azurerm provider, and ARM cannot change any of them in
  # place. Hashing keeps the replacement trigger working without putting a secret into state.
  windows_vm_secret_fingerprint = length(local.windows_vm_sensitive_os_profile) == 0 ? null : sha256(join("|", concat(
    [
      local.admin_password_windows == null ? "" : local.admin_password_windows,
      var.custom_data == null ? "" : var.custom_data,
    ],
    [for content in var.additional_unattend_contents : content.content],
  )))
}
