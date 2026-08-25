rule "diagnostic_settings" {
    enabled = false
}

# Disabled for the duration of the azurerm -> azapi migration. The rule fires on every azurerm
# resource the migration has not reached yet, so it cannot be satisfied until the migration
# removes the provider entirely. Re-enable once that is done.
rule "provider_azurerm_disallowed" {
    enabled = false
}

# The raw *_azapi outputs are deliberate escape hatches for properties the compatibility-shaped
# outputs do not expose. TFFR2 is a SHOULD.
rule "no_entire_resource_output_tffr2" {
    enabled = false
}

# The module exposes per-resource tag overrides on disks, network interfaces, public IPs,
# extensions and key vault secrets, so a resource cannot unconditionally be `tags = var.tags`.
# Whether to keep that capability is a deliberate interface decision, not something to settle by
# migrating resources one at a time. Revisit when the migration completes.
rule "azapi_resource_tag" {
    enabled = false
}