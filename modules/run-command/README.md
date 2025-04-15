<!-- BEGIN_TF_DOCS -->
# Azure Virtual Machine Run Command Module

This module is used to manage Azure Virtual Machine Run Command.

## Features

This module supports managing virtual machine run commands.

The module supports:

- Creating a run command

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Basic run command

This example shows the most basic usage of the module.

```terraform
module "avm-res-compute-virtualmachine-runcommand" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm//modules/run-command"

  name                       = "example-command"
  location                   = "uksouth"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.Compute/virtualMachines/myVM"
  script_source = {
    script = "echo Hello World"
  }
}
```

```hcl
resource "azurerm_virtual_machine_run_command" "this" {
  location           = var.location
  name               = var.name
  virtual_machine_id = var.virtualmachine_resource_id
  error_blob_uri     = var.error_blob_uri
  output_blob_uri    = var.output_blob_uri
  run_as_password    = try(var.run_as_password, null)
  run_as_user        = try(var.run_as_user, null)
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
    for_each = try(length(var.protected_parameters) > 0, false) ? var.protected_parameters : []

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
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9, < 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.116, < 5.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.116, < 5.0)

## Resources

The following resources are used by this module:

- [azurerm_virtual_machine_run_command.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_run_command) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_location"></a> [location](#input\_location)

Description: `location` - (Required): The Azure Region where the Virtual Machine Run Command should exist. Changing this forces a new Virtual Machine Run Command to be created.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: `name` - (Required): Specifies the name of this Virtual Machine Run Command. Changing this forces a new Virtual Machine Run Command to be created.

Type: `string`

### <a name="input_script_source"></a> [script\_source](#input\_script\_source)

Description: `script_source` - (Required): A source block as defined below. The source of the run command script.

Type:

```hcl
object({
    command_id = optional(string)
    script     = optional(string)
    script_uri = optional(string)
    script_uri_managed_identity = optional(object({
      client_id = optional(string)
      object_id = optional(string)
    }))
  })
```

### <a name="input_virtualmachine_resource_id"></a> [virtualmachine\_resource\_id](#input\_virtualmachine\_resource\_id)

Description: `virtualmachine_resource_id` - (Required): Specifies the resource id of the Virtual Machine to apply the Run Command to.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_error_blob_managed_identity"></a> [error\_blob\_managed\_identity](#input\_error\_blob\_managed\_identity)

Description: `error_blob_managed_identity` - (Optional): An error\_blob\_managed\_identity block as defined below. User-assigned managed Identity that has access to errorBlobUri storage blob.

Type:

```hcl
object({
    client_id = optional(string)
    object_id = optional(string)
  })
```

Default: `null`

### <a name="input_error_blob_uri"></a> [error\_blob\_uri](#input\_error\_blob\_uri)

Description: `error_blob_uri` - (Optional): Specifies the Azure storage blob where script error stream will be uploaded. It can be basic blob URI with SAS token.

Type: `string`

Default: `null`

### <a name="input_output_blob_managed_identity"></a> [output\_blob\_managed\_identity](#input\_output\_blob\_managed\_identity)

Description: `output_blob_managed_identity` - (Optional): An output\_blob\_managed\_identity block as defined below. User-assigned managed Identity that has access to outputBlobUri storage blob.

Type:

```hcl
object({
    client_id = optional(string)
    object_id = optional(string)
  })
```

Default: `null`

### <a name="input_output_blob_uri"></a> [output\_blob\_uri](#input\_output\_blob\_uri)

Description: `output_blob_uri` - (Optional): Specifies the Azure storage blob where script output stream will be uploaded. It can be basic blob URI with SAS token.

Type: `string`

Default: `null`

### <a name="input_parameters"></a> [parameters](#input\_parameters)

Description: `parameters` - (Optional): A list of parameter blocks as defined below. The parameters used by the script.

Type:

```hcl
list(object({
    name  = string
    value = string
  }))
```

Default: `[]`

### <a name="input_protected_parameters"></a> [protected\_parameters](#input\_protected\_parameters)

Description: `protected_parameters` - (Optional): A list of protected\_parameter blocks as defined below. The protected parameters used by the script.

Type:

```hcl
list(object({
    name  = string
    value = string
  }))
```

Default: `[]`

### <a name="input_run_as_password"></a> [run\_as\_password](#input\_run\_as\_password)

Description: `run_as_password` - (Optional): Specifies the user account password on the VM when executing the Virtual Machine Run Command.

Type: `string`

Default: `null`

### <a name="input_run_as_user"></a> [run\_as\_user](#input\_run\_as\_user)

Description: `run_as_user` - (Optional): Specifies the user account on the VM when executing the Virtual Machine Run Command.

Type: `string`

Default: `null`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: `tags` - (Optional) Tags of the resource.

Type: `map(string)`

Default: `null`

### <a name="input_timeouts"></a> [timeouts](#input\_timeouts)

Description: An object of timeouts to apply to the creation and destruction of resources.

- `create` - (Optional) The timeout for creating the resource.
- `delete` - (Optional) The timeout for deleting the resource.
- `update` - (Optional) The timeout for updating the resource.
- `read` - (Optional) The timeout for reading the resource.

Each time duration is parsed using this function: <https://pkg.go.dev/time#ParseDuration>.

Type:

```hcl
object({
    create = optional(string)
    delete = optional(string)
    update = optional(string)
    read   = optional(string)
  })
```

Default: `{}`

## Outputs

The following outputs are exported:

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The resource id of the virtual machine run command

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->