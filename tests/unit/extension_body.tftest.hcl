# The extension carries a secret, so the split between `body` and `sensitive_body` is the part of
# this submodule most worth pinning down. Azure never returns `protectedSettings` on a read, so a
# secret that silently fails to reach the request cannot be caught by an idempotency check - only by
# asserting on what the module builds, and by the e2e example that fails when the secret is missing
# (examples/windows_w_extension_protected_settings).
mock_provider "azapi" {}

variables {
  location                   = "eastus"
  name                       = "ext-test"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
}

run "core_attributes_are_mapped_to_arm_names" {
  command = plan

  module {
    source = "./modules/extension"
  }

  variables {
    settings = "{\"timestamp\":1}"
  }

  assert {
    condition     = local.extension_properties.publisher == "Microsoft.Compute"
    error_message = "The publisher must be mapped into the ARM body."
  }
  assert {
    condition     = local.extension_properties.typeHandlerVersion == "1.10"
    error_message = "type_handler_version must be mapped to typeHandlerVersion."
  }
  # The settings arrive as a JSON string because that is the shape the azurerm provider accepted,
  # but ARM expects a real object.
  assert {
    condition     = local.extension_properties.settings.timestamp == 1
    error_message = "The public settings must be decoded from JSON rather than sent as a string."
  }
  assert {
    condition     = !can(local.extension_properties.protectedSettings)
    error_message = "The ordinary body must never carry protected settings."
  }
}

run "omitted_optional_properties_are_absent_from_the_body" {
  command = plan

  module {
    source = "./modules/extension"
  }

  assert {
    condition     = !can(local.extension_properties.settings)
    error_message = "Omitted settings must be absent from the body rather than sent as null."
  }
  assert {
    condition     = !can(local.extension_properties.provisionAfterExtensions)
    error_message = "An empty provision_after_extensions must be absent from the body."
  }
  assert {
    condition     = !can(local.extension_properties.protectedSettingsFromKeyVault)
    error_message = "The Key Vault reference defaults to an object of nulls and must not be sent."
  }
  assert {
    condition     = local.extension_sensitive_body == null
    error_message = "An extension with no protected settings must not send a sensitive body."
  }
  assert {
    condition     = local.extension_sensitive_body_version == null
    error_message = "An extension with no protected settings must not send a sensitive body version."
  }
}

run "protected_settings_go_to_the_sensitive_body_only" {
  command = plan

  module {
    source = "./modules/extension"
  }

  variables {
    settings           = "{\"timestamp\":1}"
    protected_settings = "{\"commandToExecute\":\"exit 0\"}"
  }

  assert {
    condition     = nonsensitive(local.extension_sensitive_body.properties.protectedSettings.commandToExecute) == "exit 0"
    error_message = "The protected settings must reach ARM through sensitive_body."
  }
  assert {
    condition     = !can(local.extension_properties.protectedSettings)
    error_message = "The protected settings must never appear in the ordinary body, which is written to state."
  }
  # Both share one ARM `properties` object, so carrying the secret must not displace the public
  # settings beside it.
  assert {
    condition     = local.extension_properties.settings.timestamp == 1
    error_message = "The public settings must survive alongside the protected settings."
  }
  # sensitive_body is write-only, so without a version the provider could never tell that the secret
  # had changed and would silently skip the update the azurerm provider used to perform.
  assert {
    condition     = nonsensitive(local.extension_sensitive_body_version["properties.protectedSettings"]) == sha256("{\"commandToExecute\":\"exit 0\"}")
    error_message = "A change to the protected settings must be detectable through sensitive_body_version."
  }
}

run "the_key_vault_reference_stays_in_the_ordinary_body" {
  command = plan

  module {
    source = "./modules/extension"
  }

  variables {
    protected_settings_from_key_vault = {
      secret_url      = "https://kv-test.vault.azure.net/secrets/ext/00000000000000000000000000000000"
      source_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
    }
  }

  # This is a pointer to a secret rather than the secret itself, so it stays visible in the plan.
  assert {
    condition     = local.extension_properties.protectedSettingsFromKeyVault.secretUrl == "https://kv-test.vault.azure.net/secrets/ext/00000000000000000000000000000000"
    error_message = "The Key Vault secret URL must be mapped into the ordinary body."
  }
  assert {
    condition     = local.extension_properties.protectedSettingsFromKeyVault.sourceVault.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
    error_message = "The source vault must be nested under sourceVault.id as ARM expects."
  }
  assert {
    condition     = local.extension_sensitive_body == null
    error_message = "A Key Vault reference is not itself a secret and must not create a sensitive body."
  }
}

run "provision_after_extensions_is_sent_when_supplied" {
  command = plan

  module {
    source = "./modules/extension"
  }

  variables {
    provision_after_extensions = ["OtherExtension"]
  }

  assert {
    condition     = local.extension_properties.provisionAfterExtensions[0] == "OtherExtension"
    error_message = "provision_after_extensions must be mapped to provisionAfterExtensions."
  }
}
