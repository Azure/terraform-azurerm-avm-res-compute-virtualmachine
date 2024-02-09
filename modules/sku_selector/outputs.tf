output "sku" {
  value = try(local.deploy_skus[random_integer.deploy_sku.result].name, "no_current_valid_skus")
}