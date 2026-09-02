# The interface specification for diagnostic_settings does not match the shape this module has
# shipped since before the AzAPI migration began.
rule "avm_interface_diagnostic_settings" {
    enabled = false
}

# The module exposes per-resource tag overrides on disks, network interfaces, public IPs,
# extensions and key vault secrets, so a resource cannot unconditionally be `tags = var.tags`.
# Whether to keep that capability is a deliberate interface decision, not something to settle by
# migrating resources one at a time. Revisit when the migration completes.
rule "avm_azapi_resource_tags_required" {
    enabled = false
}
