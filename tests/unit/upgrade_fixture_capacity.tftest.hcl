mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_action" {
    defaults = {
      output = [{
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Compute/locations/eastus2/publishers/Canonical/artifacttypes/vmimage/offers/0001-com-ubuntu-server-jammy/skus/22_04-lts-gen2/versions/1.0.0"
      }]
    }
  }
}

mock_provider "random" {}

mock_provider "local" {}

run "selected_capacity_is_shared_without_zonal_constraints" {
  command = apply

  module {
    source = "./tests/integration/setup"
  }

  override_module {
    target = module.vm_sku
    outputs = {
      sku = "Standard_D4s_v5"
    }
  }

  assert {
    condition     = output.environment.sku_size == "Standard_D4s_v5"
    error_message = "The upgrade fixtures must use the selected size rather than a fixed VM size."
  }

  assert {
    condition     = output.environment.zone == null && !contains(keys(azapi_resource.attached_os_disk.body), "zones")
    error_message = "The machines and caller-owned disk must all use regional placement."
  }
}

run "no_eligible_size_fails_before_deploying_the_environment" {
  command = plan

  module {
    source = "./tests/integration/setup"
  }

  override_module {
    target = module.vm_sku
    outputs = {
      sku = "no_valid_skus_found"
    }
  }

  expect_failures = [azapi_resource.resource_group]
}
