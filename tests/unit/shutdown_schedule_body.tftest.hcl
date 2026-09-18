# Azure rejects a compute VM shutdown schedule under any name other than
# "shutdown-computevm-<machine name>", and parents it to the machine's resource group rather than to
# the machine. Those two values are what the moved block in main.shutdownschedule.tf relies on to
# adopt a schedule created by the azurerm provider, and neither is visible in an idempotency check -
# a wrong name simply creates a second schedule alongside the original. They are asserted here.
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkInterfaces/nic-test"
    }
  }
}
mock_provider "azurerm" {}
mock_provider "modtm" {}
mock_provider "random" {}
mock_provider "tls" {}

override_resource {
  target = azapi_resource.this_linux_virtual_machine
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-shutdown"
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
              id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/disks/vm-shutdown-osdisk"
            }
          }
        }
      }
    }
  }
}

variables {
  location            = "eastus"
  name                = "vm-shutdown"
  resource_group_name = "rg-test"
  zone                = "1"
  os_type             = "Linux"
  #a throwaway public key so the mocked tls provider doesn't have to produce a valid one.
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

run "no_schedule_is_created_by_default" {
  command = apply

  assert {
    condition     = length(azapi_resource.this_shutdown_schedule) == 0
    error_message = "A shutdown schedule must not be created when shutdown_schedules is empty."
  }
}

run "the_identity_azure_requires_is_reproduced" {
  command = apply

  variables {
    shutdown_schedules = {
      test_schedule = {
        daily_recurrence_time = "1700"
        timezone              = "Pacific Standard Time"
      }
    }
  }

  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].name == "shutdown-computevm-vm-shutdown"
    error_message = "The schedule name must be derived from the virtual machine name; Azure rejects any other name."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    error_message = "The schedule must be parented to the resource group, not to the virtual machine."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.targetResourceId == azapi_resource.this_linux_virtual_machine[0].id
    error_message = "The schedule must target the virtual machine this module created."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.taskType == "ComputeVmShutdownTask"
    error_message = "The schedule must be created as a compute VM shutdown task."
  }
}

run "the_schedule_is_mapped_to_arm_names" {
  command = apply

  variables {
    shutdown_schedules = {
      test_schedule = {
        daily_recurrence_time = "2300"
        timezone              = "UTC"
        notification_settings = {
          enabled         = true
          email           = "example@example.com"
          time_in_minutes = "45"
        }
        tags = {
          scope = "unit-test"
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.dailyRecurrence.time == "2300"
    error_message = "daily_recurrence_time must be mapped to dailyRecurrence.time."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.timeZoneId == "UTC"
    error_message = "timezone must be mapped to timeZoneId."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.notificationSettings.emailRecipient == "example@example.com"
    error_message = "email must be mapped to notificationSettings.emailRecipient."
  }
  # The module has always accepted this as a string, but ARM types it as an integer and rejects a
  # quoted value.
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.notificationSettings.timeInMinutes == 45
    error_message = "time_in_minutes must reach ARM as a number rather than a string."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].tags.scope == "unit-test"
    error_message = "The schedule must carry the tags supplied on the schedule definition."
  }
}

run "the_enabled_flags_are_mapped_to_arm_status_strings" {
  command = apply

  variables {
    shutdown_schedules = {
      test_schedule = {
        daily_recurrence_time = "1700"
        timezone              = "UTC"
        enabled               = false
      }
    }
  }

  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.status == "Disabled"
    error_message = "A disabled schedule must be sent as the Disabled status string."
  }
  # notification_settings defaults to disabled, and the default must survive the boolean mapping.
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.notificationSettings.status == "Disabled"
    error_message = "Notifications must default to the Disabled status string."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.notificationSettings.emailRecipient == null
    error_message = "An unset email must stay null so that ignore_null_property keeps it out of the request."
  }
  assert {
    condition     = azapi_resource.this_shutdown_schedule["test_schedule"].body.properties.notificationSettings.webhookUrl == null
    error_message = "An unset webhook must stay null so that ignore_null_property keeps it out of the request."
  }
}

run "a_second_schedule_is_rejected" {
  #variable validation is evaluated during planning, so the apply can never be reached here.
  command = plan

  variables {
    shutdown_schedules = {
      first = {
        daily_recurrence_time = "1700"
        timezone              = "UTC"
      }
      second = {
        daily_recurrence_time = "1800"
        timezone              = "UTC"
      }
    }
  }

  expect_failures = [var.shutdown_schedules]
}
