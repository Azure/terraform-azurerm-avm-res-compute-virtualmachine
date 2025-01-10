module "run_command" {
  source = "./modules/run_command"

  for_each = { for k, v in var.run_commands : k => v if v.deploy_sequence >= 3 }

  name                         = each.value.name
  location                     = each.value.location
  virtualmachine_resource_id   = local.virtualmachine_resource_id
  script_source                = each.value.source
  error_blob_managed_identity  = each.value.error_blob_managed_identity
  error_blob_uri               = each.value.error_blob_uri
  output_blob_managed_identity = each.value.output_blob_managed_identity
  output_blob_uri              = each.value.output_blob_uri
  parameters                   = each.value.parameters
  protected_parameters         = try(var.run_commands_secrets[each.key].protected_parameters, null)
  run_as_user                  = try(var.run_commands_secrets[each.key].run_as_user, null)
  run_as_password              = try(var.run_commands_secrets[each.key].run_as_password, null)

  timeouts = {
    create = coalesce(each.value.timeouts.create, var.timeouts.azurerm_virtual_machine_run_command.create)
    delete = coalesce(each.value.timeouts.delete, var.timeouts.azurerm_virtual_machine_run_command.delete)
    read   = coalesce(each.value.timeouts.read, var.timeouts.azurerm_virtual_machine_run_command.read)
    update = coalesce(each.value.timeouts.update, var.timeouts.azurerm_virtual_machine_run_command.update)
  }

  tags = each.value.tags

  depends_on = [
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    azurerm_role_assignment.this_virtual_machine,
    azurerm_role_assignment.system_managed_identity,
    module.run_command_1,
    module.run_command_2,
    azurerm_virtual_machine_extension.this_extension
  ]
}

module "run_command_1" {
  source = "./modules/run_command"

  for_each = { for k, v in var.run_commands : k => v if v.deploy_sequence == 1 }

  name                         = each.value.name
  location                     = each.value.location
  virtualmachine_resource_id   = local.virtualmachine_resource_id
  script_source                = each.value.source
  error_blob_managed_identity  = each.value.error_blob_managed_identity
  error_blob_uri               = each.value.error_blob_uri
  output_blob_managed_identity = each.value.output_blob_managed_identity
  output_blob_uri              = each.value.output_blob_uri
  parameters                   = each.value.parameters
  protected_parameters         = try(var.run_commands_secrets[each.key].protected_parameters, null)
  run_as_user                  = try(var.run_commands_secrets[each.key].run_as_user, null)
  run_as_password              = try(var.run_commands_secrets[each.key].run_as_password, null)

  timeouts = {
    create = coalesce(each.value.timeouts.create, var.timeouts.azurerm_virtual_machine_run_command.create)
    delete = coalesce(each.value.timeouts.delete, var.timeouts.azurerm_virtual_machine_run_command.delete)
    read   = coalesce(each.value.timeouts.read, var.timeouts.azurerm_virtual_machine_run_command.read)
    update = coalesce(each.value.timeouts.update, var.timeouts.azurerm_virtual_machine_run_command.update)
  }

  tags = each.value.tags

  depends_on = [
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    azurerm_role_assignment.this_virtual_machine,
    azurerm_role_assignment.system_managed_identity,
    azurerm_virtual_machine_extension.this_extension
  ]
}

module "run_command_2" {
  source = "./modules/run_command"

  for_each = { for k, v in var.run_commands : k => v if v.deploy_sequence == 2 }

  name                         = each.value.name
  location                     = each.value.location
  virtualmachine_resource_id   = local.virtualmachine_resource_id
  script_source                = each.value.source
  error_blob_managed_identity  = each.value.error_blob_managed_identity
  error_blob_uri               = each.value.error_blob_uri
  output_blob_managed_identity = each.value.output_blob_managed_identity
  output_blob_uri              = each.value.output_blob_uri
  parameters                   = each.value.parameters
  protected_parameters         = try(var.run_commands_secrets[each.key].protected_parameters, null)
  run_as_user                  = try(var.run_commands_secrets[each.key].run_as_user, null)
  run_as_password              = try(var.run_commands_secrets[each.key].run_as_password, null)

  timeouts = {
    create = coalesce(each.value.timeouts.create, var.timeouts.azurerm_virtual_machine_run_command.create)
    delete = coalesce(each.value.timeouts.delete, var.timeouts.azurerm_virtual_machine_run_command.delete)
    read   = coalesce(each.value.timeouts.read, var.timeouts.azurerm_virtual_machine_run_command.read)
    update = coalesce(each.value.timeouts.update, var.timeouts.azurerm_virtual_machine_run_command.update)
  }

  tags = each.value.tags

  depends_on = [
    azurerm_windows_virtual_machine.this,
    azurerm_linux_virtual_machine.this,
    azurerm_role_assignment.this_virtual_machine,
    azurerm_role_assignment.system_managed_identity,
    module.run_command_1,
    azurerm_virtual_machine_extension.this_extension
  ]
}

moved {
  from = azurerm_virtual_machine_run_command.this
  to   = module.run_command.azurerm_virtual_machine_run_command.this
}

moved {
  from = azurerm_virtual_machine_run_command.this_1
  to   = module.run_command.azurerm_virtual_machine_run_command.this_1
}

moved {
  from = azurerm_virtual_machine_run_command.this_2
  to   = module.run_command.azurerm_virtual_machine_run_command.this_2
}
