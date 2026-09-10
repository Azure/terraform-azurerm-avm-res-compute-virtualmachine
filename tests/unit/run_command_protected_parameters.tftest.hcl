# `protected_parameters` is a sensitive map, and the parent module passes `null` for any run command
# that has no matching `run_commands_secrets` entry (see main.runcommand.tf). Both paths have to be
# read cleanly, so the `try` guarding the length of that map is load bearing and must not be
# simplified away - `length(null)` is an error.
#
# The assertions read the locals rather than the resource because the protected parameters now
# travel in `sensitive_body`, which is write-only: the provider never stores it, so there is nothing
# to read back off `azapi_resource.this`.
mock_provider "azapi" {}

variables {
  location                   = "eastus"
  name                       = "runcmd-test"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
  script_source = {
    script = "echo hello"
  }
}

run "protected_parameters_are_rendered" {
  command = plan

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
    condition     = nonsensitive(length(local.run_command_protected_parameters)) == 2
    error_message = "Both protected parameters should be rendered into the run command."
  }
  # The map is keyed p1/p2 but ARM receives an array, so the sort keeps the order stable rather than
  # letting it drift and show up as a permanent diff.
  assert {
    condition     = nonsensitive(local.run_command_protected_parameters[0].name) == "secret1"
    error_message = "Protected parameters must be ordered by their map key."
  }
  assert {
    condition     = nonsensitive(local.run_command_sensitive_body.properties.protectedParameters[1].value) == "value2"
    error_message = "The protected parameters must reach ARM through sensitive_body."
  }
  # sensitive_body is write-only, so without a version the provider could never tell that a secret
  # had changed and would silently skip the update.
  assert {
    condition     = nonsensitive(local.run_command_sensitive_body_version["properties.protectedParameters"]) != ""
    error_message = "A change to the protected parameters must be detectable through sensitive_body_version."
  }
}

run "null_protected_parameters_render_nothing" {
  command = plan

  module {
    source = "./modules/run-command"
  }

  variables {
    protected_parameters = null
  }

  assert {
    condition     = local.run_command_protected_parameters == null
    error_message = "A null protected_parameters input must produce no protected parameters."
  }
  assert {
    condition     = local.run_command_sensitive_body == null
    error_message = "A run command with no secrets at all must not send a sensitive body."
  }
  assert {
    condition     = local.run_command_sensitive_body_version == null
    error_message = "A run command with no secrets at all must not send a sensitive body version."
  }
}

run "run_as_credentials_travel_in_the_sensitive_body" {
  command = plan

  module {
    source = "./modules/run-command"
  }

  variables {
    run_as_user     = "adminuser"
    run_as_password = "avmUnitTest123!"
  }

  # Both are declared sensitive, so putting them in `body` would mark the whole body sensitive and
  # hide every unrelated property from the plan.
  assert {
    condition     = nonsensitive(local.run_command_sensitive_body.properties.runAsUser) == "adminuser"
    error_message = "run_as_user must travel in the sensitive body."
  }
  assert {
    condition     = nonsensitive(local.run_command_sensitive_body.properties.runAsPassword) == "avmUnitTest123!"
    error_message = "run_as_password must travel in the sensitive body."
  }
  assert {
    condition     = !can(local.run_command_properties.runAsPassword)
    error_message = "run_as_password must never reach the ordinary body."
  }
  assert {
    condition     = length(nonsensitive(local.run_command_sensitive_body_version)) == 2
    error_message = "Each supplied credential needs its own version entry to be detectable."
  }
}

run "the_script_source_and_parameters_are_mapped_to_arm_names" {
  command = plan

  module {
    source = "./modules/run-command"
  }

  variables {
    parameters = {
      b_second = { name = "second", value = "2" }
      a_first  = { name = "first", value = "1" }
    }
  }

  assert {
    condition     = local.run_command_properties.source.script == "echo hello"
    error_message = "The script must be mapped to the ARM source block."
  }
  assert {
    condition     = local.run_command_properties.parameters[0].name == "first"
    error_message = "Public parameters must also be ordered by their map key."
  }
  assert {
    condition     = !can(local.run_command_properties.errorBlobUri)
    error_message = "An omitted optional property must be absent from the body rather than sent as null."
  }
}
