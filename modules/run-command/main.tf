resource "azurerm_virtual_machine_run_command" "this" {
  location           = var.location
  name               = var.name
  virtual_machine_id = var.virtualmachine_resource_id
  error_blob_uri     = var.error_blob_uri
  output_blob_uri    = var.output_blob_uri
  run_as_password    = var.run_as_password
  run_as_user        = var.run_as_user
  tags               = var.tags

  source {
    command_id = var.script_source.command_id
    script     = var.script_source.script
    script_uri = var.script_source.script_uri

    dynamic "script_uri_managed_identity" {
      for_each = var.script_source.script_uri_managed_identity == null ? [] : ["script_uri_managed_identity"]

      content {
        client_id = var.script_source.script_uri_managed_identity.client_id
        object_id = var.script_source.script_uri_managed_identity.object_id
      }
    }
  }
  dynamic "error_blob_managed_identity" {
    for_each = var.error_blob_managed_identity == null ? [] : ["error_blob_managed_identity"]

    content {
      client_id = var.error_blob_managed_identity.client_id
      object_id = var.error_blob_managed_identity.object_id
    }
  }
  dynamic "output_blob_managed_identity" {
    for_each = var.output_blob_managed_identity == null ? [] : ["output_blob_managed_identity"]

    content {
      client_id = var.output_blob_managed_identity.client_id
      object_id = var.output_blob_managed_identity.object_id
    }
  }
  dynamic "parameter" {
    for_each = var.parameters

    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
  dynamic "protected_parameter" {
    for_each = try(length(var.protected_parameters) > 0, false) ? var.protected_parameters : {}

    content {
      name  = protected_parameter.value.name
      value = protected_parameter.value.value
    }
  }
  timeouts {
    create = var.timeouts.create
    delete = var.timeouts.delete
    read   = var.timeouts.read
    update = var.timeouts.update
  }
}
