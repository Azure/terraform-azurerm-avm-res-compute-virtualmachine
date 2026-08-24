# Disabled for the duration of the azurerm -> azapi migration. The examples deploy supporting
# infrastructure with the azurerm provider, and cannot drop it until the module migration is
# complete. Re-enable once that is done.
rule "provider_azurerm_disallowed" {
    enabled = false
}