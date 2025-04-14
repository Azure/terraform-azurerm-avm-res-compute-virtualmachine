<!-- BEGIN_TF_DOCS -->
# Azure Virtual Machine Extension Module

This module is used to manage Azure Virtual Machine Extensions.

## Features

This module supports managing virtual machine extensions.

The module supports:

- Creating an extension

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Azure Monitor Agent

This example shows the most basic usage of the module.

```terraform
module "avm-res-compute-virtualmachine-extension" {
  source = "Azure/avm-res-compute-virtualmachine/azurerm//modules/extension"

  name                       = "AzureMonitorWindowsAgent"
  virtualmachine_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.Compute/virtualMachines/myVM"
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.2"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  settings                   = null
}
```

```hcl
resource "azurerm_virtual_machine_extension" "this" {
  name                        = var.name
  publisher                   = var.publisher
  type                        = var.type
  type_handler_version        = var.type_handler_version
  virtual_machine_id          = var.virtualmachine_resource_id
  auto_upgrade_minor_version  = var.auto_upgrade_minor_version
  automatic_upgrade_enabled   = var.automatic_upgrade_enabled
  failure_suppression_enabled = var.failure_suppression_enabled
  protected_settings          = var.protected_settings
  provision_after_extensions  = var.provision_after_extensions
  settings                    = var.settings
  tags                        = var.tags

  dynamic "protected_settings_from_key_vault" {
    for_each = var.protected_settings_from_key_vault != null ? [var.protected_settings_from_key_vault] : []

    content {
      secret_url      = var.protected_settings_from_key_vault.secret_url
      source_vault_id = var.protected_settings_from_key_vault.source_vault_id
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

- [azurerm_virtual_machine_extension.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_name"></a> [name](#input\_name)

Description: `name` - (Required) - Set a custom name on this value if you want the guest configuration extension to have a custom name.

Type: `string`

### <a name="input_publisher"></a> [publisher](#input\_publisher)

Description: `publisher` - (Required) - Configure the publisher for the extension to be deployed. The Publisher and Type of Virtual Machine Extensions can be found using the Azure CLI, via: az vm extension image list --location westus -o table.

Type: `string`

### <a name="input_type"></a> [type](#input\_type)

Description: `type` - (Required) - Configure the type value for the extension to be deployed.

Type: `string`

### <a name="input_type_handler_version"></a> [type\_handler\_version](#input\_type\_handler\_version)

Description: `type_handler_version` - (Required) - The type handler version for the extension. A common value is 1.0.

Type: `string`

### <a name="input_virtualmachine_resource_id"></a> [virtualmachine\_resource\_id](#input\_virtualmachine\_resource\_id)

Description: `virtualmachine_resource_id` - (Required): Specifies the resource id of the Virtual Machine to apply the Run Command to.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_auto_upgrade_minor_version"></a> [auto\_upgrade\_minor\_version](#input\_auto\_upgrade\_minor\_version)

Description: `auto_upgrade_minor_version` - (Optional) - Set this to false to avoid automatic upgrades for minor versions on the extension.  Defaults to true

Type: `bool`

Default: `true`

### <a name="input_automatic_upgrade_enabled"></a> [automatic\_upgrade\_enabled](#input\_automatic\_upgrade\_enabled)

Description: `automatic_upgrade_enabled` - (Optional) - Set this to false to avoid automatic upgrades for major versions on the extension.  Defaults to true

Type: `bool`

Default: `true`

### <a name="input_failure_suppression_enabled"></a> [failure\_suppression\_enabled](#input\_failure\_suppression\_enabled)

Description: `failure_suppression_enabled` - (Optional) - Should failures from the extension be suppressed? Possible values are true or false. Defaults to false. Operational failures such as not connecting to the VM will not be suppressed regardless of the failure\_suppression\_enabled value.

Type: `bool`

Default: `false`

### <a name="input_protected_settings"></a> [protected\_settings](#input\_protected\_settings)

Description: `protected_settings` - (Optional) - The protected\_settings passed to the extension, like settings, these are specified as a JSON object in a string. Certain VM Extensions require that the keys in the protected\_settings block are case sensitive. If you're seeing unhelpful errors, please ensure the keys are consistent with how Azure is expecting them (for instance, for the JsonADDomainExtension extension, the keys are expected to be in TitleCase.)

Type: `string`

Default: `null`

### <a name="input_protected_settings_from_key_vault"></a> [protected\_settings\_from\_key\_vault](#input\_protected\_settings\_from\_key\_vault)

Description: `protected_settings_from_key_vault` - (Optional) object for protected settings.  Cannot be used with `protected_settings`
    - `secret_url` (Required) - The Secret URL of a Key Vault Certificate. This can be sourced from the `secret_id` field within the `azurerm_key_vault_certificate` Resource.
    - `source_vault_id` (Required) - the Azure resource ID of the key vault holding the secret

Type:

```hcl
object({
    secret_url      = string
    source_vault_id = string
  })
```

Default:

```json
{
  "secret_url": null,
  "source_vault_id": null
}
```

### <a name="input_provision_after_extensions"></a> [provision\_after\_extensions](#input\_provision\_after\_extensions)

Description: `provision_after_extensions` - (Optional) - list of strings that specifies the collection of extension names after which this extension needs to be provisioned.

Type: `list(string)`

Default: `[]`

### <a name="input_settings"></a> [settings](#input\_settings)

Description: `settings` - (Optional) - The settings passed to the extension, these are specified as a JSON object in a string. Certain VM Extensions require that the keys in the settings block are case sensitive. If you're seeing unhelpful errors, please ensure the keys are consistent with how Azure is expecting them (for instance, for the JsonADDomainExtension extension, the keys are expected to be in TitleCase.)

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

Description: The resource id of the virtual machine extension

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->