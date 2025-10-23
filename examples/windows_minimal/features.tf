data "azapi_client_config" "current" {}

resource "azapi_update_resource" "allow_drop_unencrypted_vnet" {
  resource_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Compute/subscriptionFeatureRegistrations/EncryptionAtHost"
  type        = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01"
  body = {
    properties = {}
  }
}
