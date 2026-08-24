# Disabled for the duration of the azurerm -> azapi migration. This submodule still declares an
# azurerm resource and cannot drop the provider until the migration reaches it. Re-enable once
# that is done.
rule "provider_azurerm_disallowed" {
    enabled = false
}