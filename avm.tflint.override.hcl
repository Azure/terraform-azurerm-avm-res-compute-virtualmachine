rule "diagnostic_settings" {
    enabled = false
}

# The module exposes per-resource tag overrides on disks, network interfaces, public IPs,
# extensions and key vault secrets, so a resource cannot unconditionally be `tags = var.tags`.
# Whether to keep that capability is a deliberate interface decision, not something to settle by
# migrating resources one at a time. Revisit when the migration completes.
rule "azapi_resource_tag" {
    enabled = false
}
