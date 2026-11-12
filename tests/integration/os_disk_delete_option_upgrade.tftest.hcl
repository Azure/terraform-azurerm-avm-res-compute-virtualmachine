# Upgrade-and-destroy test for os_disk.delete_option.
#
# v0.21.0 created each machine with the azurerm provider, which never set a deletion policy on the
# machine, so Azure's default, Detach, applied. The provider deleted the OS disk itself after
# destroying the machine, unless its delete_os_disk_on_deletion feature was false. This module sets
# the policy on the machine instead, so the upgrade has to carry that choice over.
#
# The test deploys three machines with v0.21.0, upgrades them, destroys them with Terraform and
# checks which OS disks Azure kept:
#
# - linux_retain is built from an image and sets delete_option = "Detach", as anyone who turned
#   delete_os_disk_on_deletion off must. Its OS disk must survive.
# - windows_default is built from an image and keeps the default. Its OS disk must be deleted, as
#   it was under the provider's default.
# - linux_attached boots from a disk attached with os_managed_disk_id and keeps the default. The
#   disk belongs to the caller, so it must survive.
#
# Linux and Windows share the OS disk body, so each choice runs on one of them here and on both in
# the unit tests.

provider "azapi" {}

# v0.21.0 manages the machines with the azurerm provider, and the upgrade runs still find its
# resources in state. delete_os_disk_on_deletion only acts when the azurerm provider destroys a
# machine, which never happens here, so the provider keeps its defaults.
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

variables {
  source_image_references = {
    Linux = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    Windows = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
  }
  virtual_machines = {
    linux_retain = {
      name          = "vm-retain"
      os_type       = "Linux"
      delete_option = "Detach"
    }
    windows_default = {
      name    = "vm-win"
      os_type = "Windows"
    }
    linux_attached = {
      name           = "vm-attach"
      os_type        = "Linux"
      attach_os_disk = true
    }
  }
}

run "setup" {
  command   = apply
  state_key = "setup"

  module {
    source = "./tests/integration/setup"
  }
}

run "deploy_v0_21_0" {
  command   = apply
  state_key = "virtual_machines"

  module {
    source = "./tests/integration/fixtures/legacy"
  }

  variables {
    environment = run.setup.environment
  }

  assert {
    condition     = alltrue([for vm in values(output.virtual_machines) : vm.os_disk_delete_option == "Detach"])
    error_message = "Machines deployed by v0.21.0 should start with Azure's default OS disk policy, Detach."
  }
}

# Provider-move outputs can be unknown during plan; apply_upgrade checks VM and disk identity.
run "plan_upgrade" {
  command   = plan
  state_key = "virtual_machines"

  module {
    source = "./tests/integration/fixtures/upgraded"
  }

  variables {
    environment = run.setup.environment
  }
}

run "apply_upgrade" {
  command   = apply
  state_key = "virtual_machines"

  module {
    source = "./tests/integration/fixtures/upgraded"
  }

  variables {
    environment = run.setup.environment
  }

  assert {
    condition = alltrue([
      for key, vm in output.virtual_machines :
      vm.vm_id == run.deploy_v0_21_0.virtual_machines[key].vm_id && lower(vm.os_disk_id) == lower(run.deploy_v0_21_0.virtual_machines[key].os_disk_id)
    ])
    error_message = "Every machine should keep its VM ID and its OS disk through the upgrade. Identity comparison: ${jsonencode({
      for key, vm in output.virtual_machines : key => {
        before_vm_id                  = run.deploy_v0_21_0.virtual_machines[key].vm_id
        after_vm_id                   = vm.vm_id
        before_os_disk_id             = run.deploy_v0_21_0.virtual_machines[key].os_disk_id
        after_os_disk_id              = vm.os_disk_id
        before_replacement_properties = run.deploy_v0_21_0.virtual_machines[key].replacement_properties
        after_replacement_properties  = vm.replacement_properties
      }
    })}"
  }

  assert {
    condition     = output.virtual_machines.linux_retain.os_disk_delete_option == "Detach"
    error_message = "A machine with delete_option = \"Detach\" should keep Azure's Detach policy after the upgrade."
  }

  assert {
    condition     = output.virtual_machines.windows_default.os_disk_delete_option == "Delete"
    error_message = "By default, the upgrade should set the Delete policy on an OS disk built from an image."
  }

  assert {
    condition     = output.virtual_machines.linux_attached.os_disk_delete_option == "Detach"
    error_message = "By default, an attached OS disk should keep the Detach policy after the upgrade."
  }
}

run "destroy" {
  command   = apply
  state_key = "virtual_machines"

  module {
    source = "./tests/integration/fixtures/empty"
  }
}

run "os_disks_after_destroy" {
  command   = plan
  state_key = "os_disks"

  module {
    source = "./tests/integration/fixtures/os_disks"
  }

  variables {
    os_disk_ids       = { for key, vm in run.apply_upgrade.virtual_machines : key => vm.os_disk_id }
    resource_group_id = run.setup.environment.resource_group_id
  }

  assert {
    condition     = output.os_disks_exist.linux_retain
    error_message = "Azure should keep the OS disk of a machine with delete_option = \"Detach\"."
  }

  assert {
    condition     = !output.os_disks_exist.windows_default
    error_message = "By default, Azure should delete an OS disk built from an image with its machine."
  }

  assert {
    condition     = output.os_disks_exist.linux_attached
    error_message = "By default, Azure should keep an attached OS disk."
  }
}
