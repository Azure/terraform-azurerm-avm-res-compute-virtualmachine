<!-- BEGIN_TF_DOCS -->
# Simple Windows VM

This example demonstrates the creation of a simple Ubuntu VM with a single private IPv4 address and an auto-generated SSH key for an admin user named azureuser. The example creates a key vault for storage of the private key so it can be referenced when logging in with Bastion or downloaded as needed. Password authentication is disabled in this example.

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.6.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0, < 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_azuread"></a> [azuread](#provider\_azuread)

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0, < 4.0.0)

## Resources

The following resources are used by this module:

- [azurerm_log_analytics_workspace.this_workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) (resource)
- [azurerm_monitor_data_collection_endpoint.test](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_endpoint) (resource)
- [azurerm_monitor_data_collection_rule.test](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule) (resource)
- [azurerm_monitor_data_collection_rule_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule_association) (resource)
- [azurerm_monitor_data_collection_rule_association.this_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule_association) (resource)
- [azurerm_resource_group.this_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.this_subnet_1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.this_subnet_2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_machine_extension.azure_monitor_agent](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) (resource)
- [azurerm_virtual_network.this_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) (data source)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see https://aka.ms/avm/telemetryinfo.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

## Outputs

The following outputs are exported:

### <a name="output_vm"></a> [vm](#output\_vm)

Description: n/a

## Modules

The following Modules are called:

### <a name="module_avm-res-keyvault-vault"></a> [avm-res-keyvault-vault](#module\_avm-res-keyvault-vault)

Source: Azure/avm-res-keyvault-vault/azurerm

Version: 0.3.0

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: 0.3.0

### <a name="module_testvm"></a> [testvm](#module\_testvm)

Source: ../../

Version:

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->