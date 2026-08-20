mock_provider "azapi" {}
mock_provider "azurerm" {
  # AzAPI validates parent_id at plan time, so every mocked resource that becomes a parent must
  # carry a well-formed ARM ID rather than the generated placeholder.
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-diags"
      os_disk = {
        id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-diags-osdisk"
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "tls" {}

variables {
  location            = "eastus"
  name                = "vm-diags"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Linux"
  account_credentials = {
    admin_credentials = {
      generate_admin_password_or_ssh_key = false
      ssh_keys                           = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQChdqi+GemIsVzHEtcwAuBai8F9qfDB0vvCukphTa4WGZFJ4BJCTGhzNU3FZmBlP8/uuF8MVKXwDFsM8dSZnWldbGTBK/US6qBHK4ewu/8Fd4AqT00yPeb4354wcvyluAKqLeXh29/ILTSO/WlW4tGD/Mzx9B/qicYHyEqrYY307yAiTHps3Yi02OzG1BAprhdDz3OCyzvjgHeM8ltKokrv1/+h49oTX96pIsSVNaH6RBIsSiTSD4DAnlpeqrSacwP6az1IDFfkDob6hn2I29lJitQWuIw/Vi2hiUysPqPhs8StpXfasVfjK8NwQA0eu3KBRAGSM6OnXk+NVxeise45rjRVBKtSLd37KRQWZrOcvorlG8nZRn8TDZc8ECQbF/FJQRApT0Vf0Yxf1sdEwpcNO9/o6vnhhEY4KbFbE53xQsx0+QXdQQ+Milg7F8P/lIW9/fFVBSG07kg1qtOpj4LaHxGfwFZwyCWSAvAJ13WIlomCO/HLY3aa07zO3l6jowofJzh3WVHCaGL/Gwg1KuNYS1Hi0Hu0KXwAKeS1YQnkdfaDD7Xvf2TeP3Jzis8iDWyXrZav1XVgtOcDsOkQ3lTkdhunRGyOeqCJrxBvCAiG+N3Lb4h09SJVOIN54lBZAUFRGWjbmawNPfQkTYt8asep/yrLsfokyrBlei6rdacHPQ== avm-unit-test"]
    }
  }
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
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

run "diagnostic_settings_not_created_by_default" {
  command = apply

  assert {
    condition     = length(azapi_resource.this_virtual_machine_diagnostic_settings) == 0 && length(azapi_resource.this_network_interface_diagnostic_settings) == 0
    error_message = "No diagnostic settings must be created when none are supplied."
  }
}

run "virtual_machine_diagnostic_setting_body" {
  command = apply

  variables {
    diagnostic_settings = {
      vm_diags = {
        name                  = "vm-diag"
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
        metric_categories     = ["AllMetrics"]
        log_categories        = ["Audit"]
        log_groups            = ["allLogs"]
      }
    }
  }

  assert {
    condition     = azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].name == "vm-diag"
    error_message = "The diagnostic setting must use the supplied name."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-diags"
    error_message = "The virtual machine diagnostic setting must be parented to the virtual machine."
  }
  assert {
    condition     = azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.workspaceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
    error_message = "The workspace resource id must be mapped to workspaceId."
  }
  assert {
    condition     = length(azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.metrics) == 1 && azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.metrics[0].category == "AllMetrics"
    error_message = "Metric categories must be expanded into discrete metric objects."
  }
  assert {
    condition     = length(azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.logs) == 2
    error_message = "Log categories and log groups must both be expanded into the logs collection."
  }
  assert {
    condition     = length([for l in azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.logs : l if l.category == "Audit" && l.categoryGroup == null]) == 1
    error_message = "A log category must be emitted as category with a null categoryGroup."
  }
  assert {
    condition     = length([for l in azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.logs : l if l.categoryGroup == "allLogs" && l.category == null]) == 1
    error_message = "A log group must be emitted as categoryGroup with a null category."
  }
}

# The module has always allowed log_analytics_destination_type to be null, meaning "let Azure
# decide". These two runs pin that behaviour, which is the reason the diagnostic setting bodies are
# assembled locally rather than through avm-utl-interfaces - that module defaults the field to
# "Dedicated" and rejects null, which would silently change the destination type for consumers who
# never set it.
run "virtual_machine_dedicated_destination_type_is_sent_as_null" {
  command = apply

  variables {
    diagnostic_settings = {
      vm_diags = {
        name                           = "vm-diag"
        workspace_resource_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
        log_analytics_destination_type = "Dedicated"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.logAnalyticsDestinationType == null
    error_message = "The virtual machine diagnostic setting must send a null destination type for Dedicated, preserving the previous azurerm behaviour."
  }
}

run "virtual_machine_azure_diagnostics_destination_type_is_preserved" {
  command = apply

  variables {
    diagnostic_settings = {
      vm_diags = {
        name                           = "vm-diag"
        workspace_resource_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
        log_analytics_destination_type = "AzureDiagnostics"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_virtual_machine_diagnostic_settings["vm_diags"].body.properties.logAnalyticsDestinationType == "AzureDiagnostics"
    error_message = "A destination type other than Dedicated must be passed through unchanged."
  }
}

run "network_interface_diagnostic_setting_body" {
  command = apply

  variables {
    network_interfaces = {
      network_interface_1 = {
        name = "nic-test"
        ip_configurations = {
          ip_configuration_1 = {
            name                          = "nic-test-ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
        diagnostic_settings = {
          nic_diags = {
            name                  = "nic-diag"
            workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
            metric_categories     = ["AllMetrics"]
          }
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.this_network_interface_diagnostic_settings["network_interface_1-nic_diags"].name == "nic-diag"
    error_message = "The interface diagnostic setting must use the supplied name."
  }
  assert {
    condition     = azapi_resource.this_network_interface_diagnostic_settings["network_interface_1-nic_diags"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    error_message = "The interface diagnostic setting must be parented to its network interface, not the virtual machine."
  }
  assert {
    condition     = azapi_resource.this_network_interface_diagnostic_settings["network_interface_1-nic_diags"].body.properties.logAnalyticsDestinationType == null
    error_message = "The interface diagnostic setting must pass the destination type through unchanged, which is null when unset."
  }
}
