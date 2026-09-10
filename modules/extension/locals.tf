locals {
  # The Key Vault reference is a pointer to a secret rather than the secret itself, so it stays in
  # `body` where it remains visible in a plan. The variable defaults to an object whose members are
  # null rather than to null itself, so the members decide whether it was supplied.
  extension_protected_settings_from_key_vault = try(var.protected_settings_from_key_vault.secret_url, null) == null ? {} : {
    protectedSettingsFromKeyVault = {
      secretUrl = var.protected_settings_from_key_vault.secret_url
      sourceVault = {
        id = var.protected_settings_from_key_vault.source_vault_id
      }
    }
  }
  # Both settings blocks arrive as JSON strings because that is the shape the azurerm provider
  # accepted. ARM expects real objects, so they are decoded rather than passed through.
  extension_settings = try(var.settings, null) == null || var.settings == "" ? {} : {
    settings = jsondecode(var.settings)
  }
  extension_properties = merge(
    {
      autoUpgradeMinorVersion = var.auto_upgrade_minor_version
      enableAutomaticUpgrade  = var.automatic_upgrade_enabled
      publisher               = var.publisher
      suppressFailures        = var.failure_suppression_enabled
      type                    = var.type
      typeHandlerVersion      = var.type_handler_version
    },
    length(var.provision_after_extensions) == 0 ? {} : {
      provisionAfterExtensions = var.provision_after_extensions
    },
    local.extension_settings,
    local.extension_protected_settings_from_key_vault,
  )
  extension_protected_settings = try(var.protected_settings, null) == null || var.protected_settings == "" ? null : jsondecode(var.protected_settings)
  # The protected settings are a secret, so they are kept out of `body`. That leaves them out of
  # state entirely and keeps the rest of the body readable in a plan, rather than tainting the whole
  # body as sensitive.
  extension_sensitive_body = local.extension_protected_settings == null ? null : {
    properties = {
      protectedSettings = local.extension_protected_settings
    }
  }
  # `sensitive_body` is write-only, so the provider cannot observe the secret changing and would
  # never send an update on its own. A hash of the supplied string stands in for it: it changes
  # exactly when the protected settings change, without the secret itself entering state. The
  # azurerm provider stored the value in state in plaintext, so this is strictly less exposure than
  # before, and consumers keep the automatic updates they have today rather than having to maintain
  # a version string by hand.
  extension_sensitive_body_version = local.extension_protected_settings == null ? null : {
    "properties.protectedSettings" = sha256(var.protected_settings)
  }
}
