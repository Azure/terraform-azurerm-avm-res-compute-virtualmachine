# `protected_parameters` is a sensitive map, and the parent module passes `null` for any run command
# that has no matching `run_commands_secrets` entry (see main.runcommand.tf). Both paths have to
# iterate cleanly in the `protected_parameter` dynamic block, so the null guard on that `for_each`
# is load bearing and must not be simplified away.
mock_provider "azurerm" {}

variables {
  location                   = "eastus"
  name                       = "runcmd-test"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
  script_source = {
    script = "echo hello"
  }
}

run "protected_parameters_are_rendered" {
  command = apply

  module {
    source = "./modules/run-command"
  }

  variables {
    protected_parameters = {
      p1 = { name = "secret1", value = "value1" }
      p2 = { name = "secret2", value = "value2" }
    }
  }

  assert {
    condition     = nonsensitive(length(azurerm_virtual_machine_run_command.this.protected_parameter)) == 2
    error_message = "Both protected parameters should be rendered into the run command."
  }
}

run "null_protected_parameters_render_nothing" {
  command = apply

  module {
    source = "./modules/run-command"
  }

  variables {
    protected_parameters = null
  }

  assert {
    condition     = nonsensitive(length(azurerm_virtual_machine_run_command.this.protected_parameter)) == 0
    error_message = "A null protected_parameters input must produce no protected_parameter blocks."
  }
}
