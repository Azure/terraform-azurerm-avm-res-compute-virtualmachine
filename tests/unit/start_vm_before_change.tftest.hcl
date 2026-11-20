# Actions cannot be conditional in an action_trigger, so the start action always exists and degrades
# to a read-only GET unless the module is opted in.
mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  location                   = "eastus"
  name                       = "ext-test"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
}

run "extension_default_is_read_only" {
  command = plan

  module {
    source = "./modules/extension"
  }
}

run "extension_opt_in_plans" {
  command = plan

  module {
    source = "./modules/extension"
  }

  variables {
    start_virtual_machine_before_change = true
  }
}
