# The Key Vault data plane is addressed by host name, not by ARM resource ID, and it types the
# secret attributes as Unix time rather than as the RFC3339 strings this module has always accepted.
# Both conversions happen in the module and neither is visible in an idempotency check, so they are
# asserted here. The secret value itself is write-only and cannot be asserted on.
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "tls" {}
mock_provider "time" {
  mock_resource "time_offset" {
    defaults = {
      unix = 1893456000
    }
  }
}

override_resource {
  target = azapi_resource.this_windows_virtual_machine
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-kvsecret"
    output = {
      identity = {
        principalId = "11111111-1111-1111-1111-111111111111"
        tenantId    = "22222222-2222-2222-2222-222222222222"
      }
      properties = {
        vmId = "33333333-3333-3333-3333-333333333333"
        storageProfile = {
          osDisk = {
            managedDisk = {
              id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-kvsecret-osdisk"
            }
          }
        }
      }
    }
  }
}

variables {
  location            = "eastus"
  name                = "vm-kvsecret"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Windows"
  network_interfaces = {
    network_interface_1 = {
      name = "nic-test"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "nic-test-ipconfig1"
          private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        }
      }
    }
  }
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

run "no_secret_is_written_without_a_key_vault" {
  command = apply

  assert {
    condition     = length(azapi_data_plane_resource.admin_password) == 0
    error_message = "No credential secret may be written when no key vault is configured."
  }
}

run "the_vault_is_addressed_by_its_data_plane_host" {
  command = apply

  variables {
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      }
    }
  }

  # The scheme and the trailing slash both have to come off; the data plane rejects a parent_id that
  # carries either.
  assert {
    condition     = azapi_data_plane_resource.admin_password[0].parent_id == "kv-test.vault.azure.net"
    error_message = "The secret must be parented to the vault's data plane host name, without scheme or trailing slash."
  }
  assert {
    condition     = azapi_data_plane_resource.admin_password[0].name == "vm-kvsecret-azureuser-password"
    error_message = "The password secret must keep the generated name the module has always used."
  }
}

run "the_data_plane_host_honours_a_sovereign_cloud_suffix" {
  command = apply

  variables {
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
        dns_suffix  = "vault.usgovcloudapi.net"
      }
    }
  }

  assert {
    condition     = azapi_data_plane_resource.admin_password[0].parent_id == "kv-test.vault.usgovcloudapi.net"
    error_message = "A sovereign cloud suffix must be honoured, because the data plane host is not vault.azure.net everywhere."
  }
}

run "the_secret_attributes_are_mapped_to_unix_time" {
  command = apply

  variables {
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
        secret_configuration = {
          not_before_date = "2030-01-01T00:00:00Z"
          content_type    = "application/x-secret"
        }
      }
    }
  }

  assert {
    condition     = azapi_data_plane_resource.admin_password[0].body.attributes.exp == 1893456000
    error_message = "The expiration must reach the data plane as Unix time taken from the time_offset anchor."
  }
  # 2030-01-01T00:00:00Z is 1893456000 in Unix time. The module accepts RFC3339 and must convert.
  assert {
    condition     = azapi_data_plane_resource.admin_password[0].body.attributes.nbf == 1893456000
    error_message = "not_before_date must be converted from RFC3339 to Unix time."
  }
  assert {
    condition     = azapi_data_plane_resource.admin_password[0].body.attributes.enabled == true
    error_message = "The secret must be written in the enabled state."
  }
  assert {
    condition     = azapi_data_plane_resource.admin_password[0].body.contentType == "application/x-secret"
    error_message = "The configured content type must reach the data plane."
  }
}

run "an_unset_not_before_date_is_absent_from_the_body" {
  command = apply

  variables {
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      }
    }
  }

  # azapi_data_plane_resource has no ignore_null_property, so an unset nbf has to be left out of the
  # body rather than sent as an explicit null.
  assert {
    condition     = !can(azapi_data_plane_resource.admin_password[0].body.attributes.nbf)
    error_message = "An unset not_before_date must be absent from the body, not sent as null."
  }
}

run "secret_tags_fall_back_to_the_module_tags" {
  command = apply

  variables {
    tags = {
      environment = "unit-test"
    }
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      }
    }
  }

  assert {
    condition     = azapi_data_plane_resource.admin_password[0].body.tags.environment == "unit-test"
    error_message = "The secret must inherit the module tags when no secret tags are supplied."
  }
}

run "explicit_secret_tags_win_over_the_module_tags" {
  command = apply

  variables {
    tags = {
      environment = "unit-test"
    }
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
        secret_configuration = {
          tags = {
            scope = "credential"
          }
        }
      }
    }
  }

  assert {
    condition     = azapi_data_plane_resource.admin_password[0].body.tags.scope == "credential"
    error_message = "Secret tags must override the module tags when supplied."
  }
  assert {
    condition     = !can(azapi_data_plane_resource.admin_password[0].body.tags.environment)
    error_message = "Secret tags replace the module tags rather than merging with them."
  }
}

run "untagged_secrets_omit_the_tags_property" {
  command = apply

  variables {
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      }
    }
  }

  # No secret tags and no module tags. There is no ignore_null_property on this resource type, so
  # the property has to be left out rather than sent empty.
  assert {
    condition     = !can(azapi_data_plane_resource.admin_password[0].body.tags)
    error_message = "An untagged secret must omit tags from the body entirely."
  }
}

run "the_ssh_key_secret_is_written_for_a_generated_linux_key" {
  command = apply

  variables {
    os_type = "Linux"
    source_image_reference = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-focal"
      sku       = "20_04-lts-gen2"
      version   = "latest"
    }
    account_credentials = {
      key_vault_configuration = {
        resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      }
    }
  }

  assert {
    condition     = length(azapi_data_plane_resource.admin_ssh_key) == 1
    error_message = "A generated Linux ssh key must be written to the configured key vault."
  }
  assert {
    condition     = azapi_data_plane_resource.admin_ssh_key[0].name == "vm-kvsecret-azureuser-ssh-private-key"
    error_message = "The ssh key secret must keep the generated name the module has always used."
  }
  assert {
    condition     = azapi_data_plane_resource.admin_ssh_key[0].parent_id == "kv-test.vault.azure.net"
    error_message = "The ssh key secret must be parented to the vault's data plane host name."
  }
  # A Linux machine with password authentication disabled writes the ssh key, not a password.
  assert {
    condition     = length(azapi_data_plane_resource.admin_password) == 0
    error_message = "No password secret may be written when password authentication is disabled."
  }
}
