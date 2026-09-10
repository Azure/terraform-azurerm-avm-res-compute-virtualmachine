locals {
  # The azurerm provider rendered these as repeatable blocks whose order followed the map's lexical
  # key order. ARM models them as arrays, so the keys are sorted explicitly to keep the order that
  # existing state was built with; an unstable order would show up as a permanent diff.
  #
  # Both maps are read through `try`, because the parent passes `null` rather than an empty map for
  # any run command with no matching `run_commands_secrets` entry (see main.runcommand.tf), and
  # `length(null)` is an error. The azurerm implementation guarded the same case on its dynamic
  # block, so this is load bearing and must not be simplified away.
  run_command_parameters = try(length(var.parameters), 0) == 0 ? {} : {
    parameters = [
      for key in sort(keys(var.parameters)) : {
        name  = var.parameters[key].name
        value = var.parameters[key].value
      }
    ]
  }
  run_command_source = merge(
    var.script_source.command_id == null ? {} : { commandId = var.script_source.command_id },
    var.script_source.script == null ? {} : { script = var.script_source.script },
    var.script_source.script_uri == null ? {} : { scriptUri = var.script_source.script_uri },
    try(var.script_source.script_uri_managed_identity, null) == null ? {} : {
      scriptUriManagedIdentity = merge(
        var.script_source.script_uri_managed_identity.client_id == null ? {} : { clientId = var.script_source.script_uri_managed_identity.client_id },
        var.script_source.script_uri_managed_identity.object_id == null ? {} : { objectId = var.script_source.script_uri_managed_identity.object_id },
      )
    },
  )
  run_command_error_blob_managed_identity = var.error_blob_managed_identity == null ? {} : {
    errorBlobManagedIdentity = merge(
      var.error_blob_managed_identity.client_id == null ? {} : { clientId = var.error_blob_managed_identity.client_id },
      var.error_blob_managed_identity.object_id == null ? {} : { objectId = var.error_blob_managed_identity.object_id },
    )
  }
  run_command_output_blob_managed_identity = var.output_blob_managed_identity == null ? {} : {
    outputBlobManagedIdentity = merge(
      var.output_blob_managed_identity.client_id == null ? {} : { clientId = var.output_blob_managed_identity.client_id },
      var.output_blob_managed_identity.object_id == null ? {} : { objectId = var.output_blob_managed_identity.object_id },
    )
  }
  # Each optional member is merged in as its own single-attribute object rather than through one
  # conditional, because Terraform can only unify `{}` with an object whose values all share a type.
  run_command_properties = merge(
    {
      source = local.run_command_source
    },
    var.error_blob_uri == null ? {} : { errorBlobUri = var.error_blob_uri },
    var.output_blob_uri == null ? {} : { outputBlobUri = var.output_blob_uri },
    local.run_command_parameters,
    local.run_command_error_blob_managed_identity,
    local.run_command_output_blob_managed_identity,
  )
  run_command_protected_parameters = try(length(var.protected_parameters), 0) == 0 ? null : [
    for key in sort(keys(var.protected_parameters)) : {
      name  = var.protected_parameters[key].name
      value = var.protected_parameters[key].value
    }
  ]
  # `run_as_user` is carried here rather than in `body` because the module declares it sensitive.
  # Interpolating a sensitive value into `body` would mark the entire body sensitive and hide every
  # unrelated property from the plan.
  run_command_sensitive_properties = merge(
    local.run_command_protected_parameters == null ? {} : { protectedParameters = local.run_command_protected_parameters },
    var.run_as_password == null ? {} : { runAsPassword = var.run_as_password },
    var.run_as_user == null ? {} : { runAsUser = var.run_as_user },
  )
  run_command_has_secrets = local.run_command_protected_parameters != null || var.run_as_password != null || var.run_as_user != null
  run_command_sensitive_body = local.run_command_has_secrets ? {
    properties = local.run_command_sensitive_properties
  } : null
  # `sensitive_body` is write-only, so the provider cannot observe these values changing and would
  # never send an update on its own. A hash per body path stands in for each of them: it changes
  # exactly when that value changes, without the secret itself entering state. The azurerm provider
  # stored all three in state in plaintext, so this is strictly less exposure than before.
  run_command_sensitive_body_version = local.run_command_has_secrets ? merge(
    local.run_command_protected_parameters == null ? {} : {
      "properties.protectedParameters" = sha256(jsonencode(local.run_command_protected_parameters))
    },
    var.run_as_password == null ? {} : { "properties.runAsPassword" = sha256(var.run_as_password) },
    var.run_as_user == null ? {} : { "properties.runAsUser" = sha256(var.run_as_user) },
  ) : null
}
