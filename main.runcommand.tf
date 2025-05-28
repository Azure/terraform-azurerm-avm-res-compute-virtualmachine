module "run_command" {
  source   = "./modules/run-command"
  for_each = { for k, v in var.run_commands : k => v if v.deploy_sequence >= 3 }

  location                     = each.value.location
  name                         = each.value.name
  script_source                = each.value.script_source
  virtualmachine_resource_id   = local.virtualmachine_resource_id
  error_blob_managed_identity  = each.value.error_blob_managed_identity
  error_blob_uri               = each.value.error_blob_uri
  output_blob_managed_identity = each.value.output_blob_managed_identity
  output_blob_uri              = each.value.output_blob_uri
  parameters                   = each.value.parameters
  protected_parameters         = try(var.run_commands_secrets[each.key].protected_parameters, null)
  run_as_password              = try(var.run_commands_secrets[each.key].run_as_password, null)
  run_as_user                  = try(var.run_commands_secrets[each.key].run_as_user, null)
  tags                         = each.value.tags
  timeouts = {
    create = coalesce(try(each.value.timeouts.create, null), var.timeouts.azurerm_virtual_machine_run_command.create)
    delete = coalesce(try(each.value.timeouts.delete, null), var.timeouts.azurerm_virtual_machine_run_command.delete)
    read   = coalesce(try(each.value.timeouts.read, null), var.timeouts.azurerm_virtual_machine_run_command.read)
    update = coalesce(try(each.value.timeouts.update, null), var.timeouts.azurerm_virtual_machine_run_command.update)
  }

  depends_on = [
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    azurerm_role_assignment.this_virtual_machine,
    azurerm_role_assignment.system_managed_identity,
    module.run_command_1,
    module.run_command_2,
    module.extension
  ]
}

module "run_command_1" {
  source   = "./modules/run-command"
  for_each = { for k, v in var.run_commands : k => v if v.deploy_sequence == 1 }

  location                     = each.value.location
  name                         = each.value.name
  script_source                = each.value.script_source
  virtualmachine_resource_id   = local.virtualmachine_resource_id
  error_blob_managed_identity  = each.value.error_blob_managed_identity
  error_blob_uri               = each.value.error_blob_uri
  output_blob_managed_identity = each.value.output_blob_managed_identity
  output_blob_uri              = each.value.output_blob_uri
  parameters                   = each.value.parameters
  protected_parameters         = try(var.run_commands_secrets[each.key].protected_parameters, null)
  run_as_password              = try(var.run_commands_secrets[each.key].run_as_password, null)
  run_as_user                  = try(var.run_commands_secrets[each.key].run_as_user, null)
  tags                         = each.value.tags
  timeouts = {
    create = coalesce(try(each.value.timeouts.create, null), var.timeouts.azurerm_virtual_machine_run_command.create)
    delete = coalesce(try(each.value.timeouts.delete, null), var.timeouts.azurerm_virtual_machine_run_command.delete)
    read   = coalesce(try(each.value.timeouts.read, null), var.timeouts.azurerm_virtual_machine_run_command.read)
    update = coalesce(try(each.value.timeouts.update, null), var.timeouts.azurerm_virtual_machine_run_command.update)
  }

  depends_on = [
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    azurerm_role_assignment.this_virtual_machine,
    azurerm_role_assignment.system_managed_identity,
    module.extension
  ]
}

module "run_command_2" {
  source   = "./modules/run-command"
  for_each = { for k, v in var.run_commands : k => v if v.deploy_sequence == 2 }

  location                     = each.value.location
  name                         = each.value.name
  script_source                = each.value.script_source
  virtualmachine_resource_id   = local.virtualmachine_resource_id
  error_blob_managed_identity  = each.value.error_blob_managed_identity
  error_blob_uri               = each.value.error_blob_uri
  output_blob_managed_identity = each.value.output_blob_managed_identity
  output_blob_uri              = each.value.output_blob_uri
  parameters                   = each.value.parameters
  protected_parameters         = try(var.run_commands_secrets[each.key].protected_parameters, null)
  run_as_password              = try(var.run_commands_secrets[each.key].run_as_password, null)
  run_as_user                  = try(var.run_commands_secrets[each.key].run_as_user, null)
  tags                         = each.value.tags
  timeouts = {
    create = coalesce(try(each.value.timeouts.create, null), var.timeouts.azurerm_virtual_machine_run_command.create)
    delete = coalesce(try(each.value.timeouts.delete, null), var.timeouts.azurerm_virtual_machine_run_command.delete)
    read   = coalesce(try(each.value.timeouts.read, null), var.timeouts.azurerm_virtual_machine_run_command.read)
    update = coalesce(try(each.value.timeouts.update, null), var.timeouts.azurerm_virtual_machine_run_command.update)
  }

  depends_on = [
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    azurerm_role_assignment.this_virtual_machine,
    azurerm_role_assignment.system_managed_identity,
    module.run_command_1,
    module.extension
  ]
}
