terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# tflint-ignore: terraform_module_provider_declaration, terraform_output_separate, terraform_variable_separate
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.5.0"

  availability_zones_filter = true
}

locals {
  deployment_region = "canadacentral"
  tags = {
    scenario = "linux_custom_data_gzip"
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

resource "azurerm_resource_group" "this_rg" {
  location = local.deployment_region
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}

module "vm_sku" {
  source  = "Azure/avm-utl-sku-finder/azapi"
  version = "0.3.0"

  location      = azurerm_resource_group.this_rg.location
  cache_results = true
  vm_filters = {
    min_vcpus                      = 2
    max_vcpus                      = 2
    encryption_at_host_supported   = false
    accelerated_networking_enabled = true
    premium_io_supported           = true
    location_zone                  = random_integer.zone_index.result
  }

  depends_on = [random_integer.zone_index]
}

module "natgateway" {
  source  = "Azure/avm-res-network-natgateway/azurerm"
  version = "0.2.1"

  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.nat_gateway.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  enable_telemetry    = true
  public_ips = {
    public_ip_1 = {
      name = "nat_gw_pip1"
    }
  }
  tags = local.tags
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "=0.8.1"

  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  name                = module.naming.virtual_network.name_unique
  subnets = {
    vm_subnet_1 = {
      name             = "${module.naming.subnet.name_unique}-1"
      address_prefixes = ["10.0.1.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
  }
  tags = local.tags
}

data "azurerm_client_config" "current" {}

module "avm_res_keyvault_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "=0.10.0"

  location            = azurerm_resource_group.this_rg.location
  name                = "${module.naming.key_vault.name_unique}-cd-gzip"
  resource_group_name = azurerm_resource_group.this_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  network_acls = {
    default_action = "Allow"
  }
  role_assignments = {
    deployment_user_secrets = {
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }
  tags = local.tags
  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }
}

# Plain text cloud-init (no gzip) — base64 only
data "cloudinit_config" "plaintext" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-CLOUDINIT
      #cloud-config
      write_files:
        - path: /tmp/hello-plaintext.txt
          content: "Hello from plaintext cloud-init"
    CLOUDINIT
  }
}

# Gzipped cloud-init — this is the scenario that was broken (Issue #207)
data "cloudinit_config" "gzipped" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-CLOUDINIT
      #cloud-config
      write_files:
        - path: /tmp/hello-gzipped.txt
          content: "Hello from gzipped cloud-init"
    CLOUDINIT
  }
}

# VM with plain text (non-gzipped) custom_data
module "vm_plaintext_custom_data" {
  source = "../../"

  location = azurerm_resource_group.this_rg.location
  name     = "${module.naming.virtual_machine.name_unique}-plain"
  network_interfaces = {
    network_interface_1 = {
      name = "${module.naming.network_interface.name_unique}-plain"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-plain-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }
  resource_group_name = azurerm_resource_group.this_rg.name
  zone                = random_integer.zone_index.result
  account_credentials = {
    key_vault_configuration = {
      resource_id = module.avm_res_keyvault_vault.resource_id
    }
  }
  custom_data                = data.cloudinit_config.plaintext.rendered
  enable_telemetry           = var.enable_telemetry
  encryption_at_host_enabled = false
  os_type                    = "Linux"
  sku_size         = module.vm_sku.sku
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

# VM with gzipped custom_data — previously rejected by validation (Issue #207)
module "vm_gzipped_custom_data" {
  source = "../../"

  location = azurerm_resource_group.this_rg.location
  name     = "${module.naming.virtual_machine.name_unique}-gzip"
  network_interfaces = {
    network_interface_1 = {
      name = "${module.naming.network_interface.name_unique}-gzip"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-gzip-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
        }
      }
    }
  }
  resource_group_name = azurerm_resource_group.this_rg.name
  zone                = random_integer.zone_index.result
  account_credentials = {
    key_vault_configuration = {
      resource_id = module.avm_res_keyvault_vault.resource_id
    }
  }
  custom_data                = data.cloudinit_config.gzipped.rendered
  enable_telemetry           = var.enable_telemetry
  encryption_at_host_enabled = false
  os_type                    = "Linux"
  sku_size         = module.vm_sku.sku
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
