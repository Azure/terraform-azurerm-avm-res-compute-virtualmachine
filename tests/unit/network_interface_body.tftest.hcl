mock_provider "azapi" {
  # The virtual machine is still an azurerm resource and parses each network_interface_ids entry as
  # an ARM ID, so the mocked interface must carry a well-formed one rather than the generated
  # placeholder.
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

variables {
  location            = "eastus"
  name                = "vm-nic-body"
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
    nic1 = {
      name = "nic-test"
      ip_configurations = {
        ipconfig1 = {
          name                          = "ipconfig1"
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

run "ip_configuration_defaults_are_mapped_to_arm_names" {
  command = apply

  assert {
    condition     = local.nic_bodies["nic1"].properties.ipConfigurations[0].name == "ipconfig1"
    error_message = "The IP configuration name must be carried into the interface body."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.primary == true
    error_message = "is_primary_ipconfiguration must map to properties.primary."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.privateIPAllocationMethod == "Dynamic"
    error_message = "private_ip_address_allocation must map to properties.privateIPAllocationMethod."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.privateIPAddressVersion == "IPv4"
    error_message = "private_ip_address_version must map to properties.privateIPAddressVersion."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.subnet.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
    error_message = "private_ip_subnet_resource_id must map to properties.subnet.id."
  }
}

run "omitted_optional_properties_are_absent_from_the_body" {
  command = apply

  assert {
    condition     = !can(local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.privateIPAddress)
    error_message = "A null private_ip_address must be omitted rather than sent as null."
  }
  assert {
    condition     = !can(local.nic_bodies["nic1"].properties.dnsSettings)
    error_message = "dnsSettings must be omitted when neither dns_servers nor internal_dns_name_label is supplied."
  }
  assert {
    condition     = !can(local.nic_bodies["nic1"].properties.networkSecurityGroup)
    error_message = "networkSecurityGroup must be omitted when no network security group is supplied."
  }
  assert {
    condition     = !can(local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.applicationSecurityGroups)
    error_message = "applicationSecurityGroups must be omitted when none are supplied."
  }
}

run "interface_level_flags_and_dns_are_mapped" {
  command = apply

  variables {
    network_interfaces = {
      nic1 = {
        name                           = "nic-test"
        accelerated_networking_enabled = true
        ip_forwarding_enabled          = true
        dns_servers                    = ["10.0.0.4", "10.0.0.5"]
        internal_dns_name_label        = "internal-label"
        ip_configurations = {
          ipconfig1 = {
            name                          = "ipconfig1"
            private_ip_address            = "10.0.0.10"
            private_ip_address_allocation = "Static"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
      }
    }
  }

  assert {
    condition     = local.nic_bodies["nic1"].properties.enableAcceleratedNetworking == true
    error_message = "accelerated_networking_enabled must map to properties.enableAcceleratedNetworking."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.enableIPForwarding == true
    error_message = "ip_forwarding_enabled must map to properties.enableIPForwarding."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.dnsSettings.dnsServers == tolist(["10.0.0.4", "10.0.0.5"])
    error_message = "dns_servers must map to properties.dnsSettings.dnsServers."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.dnsSettings.internalDnsNameLabel == "internal-label"
    error_message = "internal_dns_name_label must map to properties.dnsSettings.internalDnsNameLabel."
  }
  assert {
    condition     = local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.privateIPAddress == "10.0.0.10"
    error_message = "A supplied private_ip_address must appear in the body."
  }
}

run "associations_are_folded_into_the_interface_body" {
  command = apply

  variables {
    network_interfaces = {
      nic1 = {
        name = "nic-test"
        network_security_groups = {
          nsg1 = {
            network_security_group_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-test"
          }
        }
        application_security_groups = {
          asg1 = {
            application_security_group_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/applicationSecurityGroups/asg-test"
          }
        }
        ip_configurations = {
          ipconfig1 = {
            name                          = "ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
            load_balancer_backend_pools = {
              lb1 = {
                load_balancer_backend_pool_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/loadBalancers/lb-test/backendAddressPools/pool-test"
              }
            }
            load_balancer_nat_rules = {
              nat1 = {
                load_balancer_nat_rule_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/loadBalancers/lb-test/inboundNatRules/nat-test"
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = local.nic_bodies["nic1"].properties.networkSecurityGroup.id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-test"
    error_message = "The network security group association must become properties.networkSecurityGroup on the interface."
  }
  assert {
    condition     = one(local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.applicationSecurityGroups).id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/applicationSecurityGroups/asg-test"
    error_message = "The interface-level application security group must be replicated onto each IP configuration."
  }
  assert {
    condition     = one(local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.loadBalancerBackendAddressPools).id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/loadBalancers/lb-test/backendAddressPools/pool-test"
    error_message = "The load balancer backend pool association must become a property of the IP configuration."
  }
  assert {
    condition     = one(local.nic_bodies["nic1"].properties.ipConfigurations[0].properties.loadBalancerInboundNatRules).id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/loadBalancers/lb-test/inboundNatRules/nat-test"
    error_message = "The load balancer NAT rule association must become a property of the IP configuration."
  }
}

run "more_than_one_network_security_group_is_rejected" {
  command = plan

  variables {
    network_interfaces = {
      nic1 = {
        name = "nic-test"
        network_security_groups = {
          nsg1 = {
            network_security_group_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-one"
          }
          nsg2 = {
            network_security_group_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-two"
          }
        }
        ip_configurations = {
          ipconfig1 = {
            name                          = "ipconfig1"
            private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
          }
        }
      }
    }
  }

  expect_failures = [azapi_resource.virtualmachine_network_interfaces]
}
