resource "azurerm_virtual_machine_run_command" "this" {
  for_each = var.run_commands

  location           = each.value.location
  name               = each.value.name
  virtual_machine_id = local.virtualmachine_resource_id
  error_blob_uri     = each.value.error_blob_uri
  output_blob_uri    = each.value.output_blob_uri
  run_as_password    = try(var.run_commands_secrets[each.key].run_as_password, null)
  run_as_user        = try(var.run_commands_secrets[each.key].run_as_user, null)
  tags               = each.value.tags

  source {
    command_id = each.value.source.command_id
    script     = each.value.source.script
    script_uri = each.value.source.script_uri

    dynamic "script_uri_managed_identity" {
      for_each = each.value.source.script_uri_managed_identity == null ? [] : ["script_uri_managed_identity"]

      content {
        client_id = each.value.source.script_uri_managed_identity.client_id
        object_id = each.value.source.script_uri_managed_identity.object_id
      }
    }
  }
  dynamic "error_blob_managed_identity" {
    for_each = each.value.error_blob_managed_identity == null ? [] : ["error_blob_managed_identity"]

    content {
      client_id = each.value.error_blob_managed_identity.client_id
      object_id = each.value.error_blob_managed_identity.object_id
    }
  }
  dynamic "output_blob_managed_identity" {
    for_each = each.value.output_blob_managed_identity == null ? [] : ["output_blob_managed_identity"]

    content {
      client_id = each.value.output_blob_managed_identity.client_id
      object_id = each.value.output_blob_managed_identity.object_id
    }
  }
  dynamic "parameter" {
    for_each = each.value.parameters

    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
  dynamic "protected_parameter" {
    for_each = try(length(var.run_commands_secrets[each.key].protected_parameters) > 0, false) ? var.run_commands_secrets[each.key].protected_parameters : []

    content {
      name  = protected_parameter.value.name
      value = protected_parameter.value.value
    }
  }

  depends_on = [
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    azurerm_role_assignment.this_virtual_machine,
    azurerm_role_assignment.system_managed_identity
  ]
}