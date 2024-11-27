<!-- BEGIN_TF_DOCS -->
# Ubuntu VM with a number of common VM features

This example demonstrates the creation of a simple Ubuntu VM with the following features:

    - a single private IPv4 address
    - an user provided SSH key for an admin user named azureuser
    - password authentication disabled
    - a default OS 128gb OS disk encrypted with a disk encryption set
    - deploys into a randomly selected region
    - An additional data disk encrypted with a disk encryption set
    - A User Assigned and System Assigned Managed identity Configured
    - Role Assignment on the individual resource
    - Role Assignment giving the System Assigned Managed Identity access to the key vault keys

It includes the following resources in addition to the VM resource:

    - A Vnet with two subnets
    - A keyvault for storing the login secrets
    - An optional subnet, public ip, and bastion which can be enabled by uncommenting the bastion resources when running the example.

```hcl
terraform {
  required_version = "~> 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# tflint-ignore: terraform_module_provider_declaration, terraform_output_separate, terraform_variable_separate
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.3.0"

  availability_zones_filter = true
}

locals {
  #deployment_region = module.regions.regions[random_integer.region_index.result].name
  deployment_region = "canadacentral" #temporarily pinning on single region 
  tags = {
    scenario = "Default"
  }
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions_by_name) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.deployment_region].zones)
  min = 1
}

module "get_valid_sku_for_deployment_region" {
  source = "../../modules/sku_selector"

  deployment_region = local.deployment_region
}

resource "azurerm_resource_group" "this_rg" {
  location = local.deployment_region
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}

resource "azurerm_resource_group" "this_rg_secondary" {
  location = local.deployment_region
  name     = "${module.naming.resource_group.name_unique}-alt"
  tags     = local.tags
}

resource "azurerm_virtual_network" "this_vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

resource "azurerm_subnet" "this_subnet_1" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "${module.naming.subnet.name_unique}-1"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}

resource "azurerm_subnet" "this_subnet_2" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "${module.naming.subnet.name_unique}-2"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}

#Uncomment this section if you would like to include a bastion resource with this example.
resource "azurerm_subnet" "bastion_subnet" {
  address_prefixes     = ["10.0.3.0/24"]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this_rg.name
  virtual_network_name = azurerm_virtual_network.this_vnet.name
}

resource "azurerm_public_ip" "bastionpip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.bastion_host.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name

  ip_configuration {
    name                 = "${module.naming.bastion_host.name_unique}-ipconf"
    public_ip_address_id = azurerm_public_ip.bastionpip.id
    subnet_id            = azurerm_subnet.bastion_subnet.id
  }
}



data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

module "avm_res_keyvault_vault" {
  source                      = "Azure/avm-res-keyvault-vault/azurerm"
  version                     = "=0.9.1"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  name                        = module.naming.key_vault.name_unique
  resource_group_name         = azurerm_resource_group.this_rg.name
  location                    = azurerm_resource_group.this_rg.location
  enabled_for_disk_encryption = true
  network_acls = {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  role_assignments = {
    deployment_user_secrets = { #give the deployment user access to secrets
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
    deployment_user_keys = { #give the deployment user access to keys
      role_definition_id_or_name = "Key Vault Crypto Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
    user_managed_identity_keys = { #give the user assigned managed identity for the disk encryption set access to keys
      role_definition_id_or_name = "Key Vault Crypto Officer"
      principal_id               = azurerm_user_assigned_identity.example_identity.principal_id
      principal_type             = "ServicePrincipal"
    }
  }

  wait_for_rbac_before_key_operations = {
    create = "60s"
  }

  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }

  tags = local.tags

  keys = {
    des_key = {
      name     = "des-disk-key"
      key_type = "RSA"
      key_size = 2048

      key_opts = [
        "decrypt",
        "encrypt",
        "sign",
        "unwrapKey",
        "verify",
        "wrapKey",
      ]
    }
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "admin_ssh_key" {
  key_vault_id = module.avm_res_keyvault_vault.resource_id
  name         = "azureuser-ssh-private-key"
  value        = tls_private_key.this.private_key_pem

  depends_on = [
    module.avm_res_keyvault_vault
  ]
}

resource "tls_private_key" "this_2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "admin_ssh_key_2" {
  key_vault_id = module.avm_res_keyvault_vault.resource_id
  name         = "azureuser-ssh-private-key-2"
  value        = tls_private_key.this_2.private_key_pem

  depends_on = [
    module.avm_res_keyvault_vault
  ]
}

resource "azurerm_disk_encryption_set" "this" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.disk_encryption_set.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  key_vault_key_id    = module.avm_res_keyvault_vault.keys_resource_ids.des_key.id
  tags                = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.example_identity.id]
  }
}

module "testvm" {
  source = "../../"
  #source = "Azure/avm-res-compute-virtualmachine/azurerm"
  #version = "0.17.0

  admin_username                     = "azureuser"
  enable_telemetry                   = var.enable_telemetry
  encryption_at_host_enabled         = true
  generate_admin_password_or_ssh_key = false
  location                           = azurerm_resource_group.this_rg.location
  name                               = module.naming.virtual_machine.name_unique
  resource_group_name                = azurerm_resource_group.this_rg.name
  os_type                            = "Linux"
  sku_size                           = module.get_valid_sku_for_deployment_region.sku
  zone                               = random_integer.zone_index.result

  admin_ssh_keys = [
    {
      public_key = tls_private_key.this.public_key_openssh
      username   = "azureuser" #the username must match the admin_username currently.
    },
    {
      public_key = tls_private_key.this_2.public_key_openssh
      username   = "azureuser" #the username must match the admin_username currently.
    }
  ]

  data_disk_managed_disks = {
    disk1 = {
      name                   = "${module.naming.managed_disk.name_unique}-lun0"
      storage_account_type   = "Premium_LRS"
      lun                    = 0
      caching                = "ReadWrite"
      disk_size_gb           = 32
      disk_encryption_set_id = azurerm_disk_encryption_set.this.id
      resource_group_name    = azurerm_resource_group.this_rg_secondary.name
      role_assignments = {
        role_assignment_2 = {
          principal_id               = data.azurerm_client_config.current.client_id
          role_definition_id_or_name = "Contributor"
          description                = "Assign the Contributor role to the deployment user on this managed disk resource scope."
          principal_type             = "ServicePrincipal"
        }
      }
    }
  }

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  network_interfaces = {
    network_interface_1 = {
      name                           = "${module.naming.network_interface.name_unique}-1"
      accelerated_networking_enabled = true
      ip_forwarding_enabled          = true
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-nic1-ipconfig1"
          private_ip_subnet_resource_id = azurerm_subnet.this_subnet_1.id
        }
      }
      resource_group_name = azurerm_resource_group.this_rg_secondary.name
    }
    network_interface_2 = {
      name                  = "${module.naming.network_interface.name_unique}-2"
      ip_forwarding_enabled = true
      ip_configurations = {
        ip_configuration_avs_facing = {
          name                          = "${module.naming.network_interface.name_unique}-nic2-ipconfig1"
          private_ip_subnet_resource_id = azurerm_subnet.this_subnet_2.id
        }
      }
    }
  }

  os_disk = {
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_encryption_set_id = azurerm_disk_encryption_set.this.id
  }

  role_assignments_system_managed_identity = {
    role_assignment_1 = {
      scope_resource_id          = module.avm_res_keyvault_vault.resource_id
      role_definition_id_or_name = "Key Vault Secrets Officer"
      description                = "Assign the Key Vault Secrets Officer role to the virtual machine's system managed identity"
      principal_type             = "ServicePrincipal"
    }
  }

  role_assignments = {
    role_assignment_2 = {
      principal_id               = data.azurerm_client_config.current.client_id
      role_definition_id_or_name = "Virtual Machine Contributor"
      description                = "Assign the Virtual Machine Contributor role to the deployment user on this virtual machine resource scope."
      principal_type             = "ServicePrincipal"
    }
  }

  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  tags = local.tags

  depends_on = [
    module.avm_res_keyvault_vault
  ]
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.6)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.116, < 5.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.6)

- <a name="requirement_tls"></a> [tls](#requirement\_tls) (~> 4.0)

## Resources

The following resources are used by this module:

- [azurerm_bastion_host.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) (resource)
- [azurerm_disk_encryption_set.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/disk_encryption_set) (resource)
- [azurerm_key_vault_secret.admin_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_key_vault_secret.admin_ssh_key_2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_public_ip.bastionpip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.this_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_resource_group.this_rg_secondary](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.bastion_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.this_subnet_1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.this_subnet_2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_user_assigned_identity.example_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) (resource)
- [azurerm_virtual_network.this_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [random_integer.zone_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) (resource)
- [tls_private_key.this_2](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) (resource)
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

No outputs.

## Modules

The following Modules are called:

### <a name="module_avm_res_keyvault_vault"></a> [avm\_res\_keyvault\_vault](#module\_avm\_res\_keyvault\_vault)

Source: Azure/avm-res-keyvault-vault/azurerm

Version: =0.9.1

### <a name="module_get_valid_sku_for_deployment_region"></a> [get\_valid\_sku\_for\_deployment\_region](#module\_get\_valid\_sku\_for\_deployment\_region)

Source: ../../modules/sku_selector

Version:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: ~> 0.4

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/avm-utl-regions/azurerm

Version: 0.3.0

### <a name="module_testvm"></a> [testvm](#module\_testvm)

Source: ../../

Version:

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->