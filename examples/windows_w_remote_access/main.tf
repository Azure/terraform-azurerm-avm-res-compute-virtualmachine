terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
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
  version = "~> 0.4"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.5.0"

  availability_zones_filter = true
}
locals {
  admin_username    = "azureuser"
  deployment_region = "canadacentral" #temporarily pinning on single region
  inline_remote_exec = [
    "schtasks /Create /TN \"\\AVM\\RotateWinRMListenerThumbprint\" /SC MINUTE /MO 1 /TR \"\"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe\" -ExecutionPolicy Bypass -Command & { . 'C:\\AzureData\\w_sc_task_rotate_winrms_cert.ps1'; Update-WinRMCertificate -CommonName 'CN=${module.naming.virtual_machine.name_unique}' -WinRmsPort ${local.winrms_port} }\" /RU \"SYSTEM\" /RL HIGHEST /F"
  ]
  os_type = "Windows"
  tags = {
    scenario = "basic_windows_w_winrms"
  }
  winrms_port = 15986
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
    encryption_at_host_supported   = true
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
      network_security_group = {
        id = azurerm_network_security_group.remote.id
      }
    }
    vm_subnet_2 = {
      name             = "${module.naming.subnet.name_unique}-2"
      address_prefixes = ["10.0.2.0/24"]
      nat_gateway = {
        id = module.natgateway.resource_id
      }
    }
    AzureBastionSubnet = {
      name             = "AzureBastionSubnet"
      address_prefixes = ["10.0.3.0/24"]
    }
  }
}

resource "azurerm_network_security_group" "remote" {
  location            = azurerm_resource_group.this_rg.location
  name                = "nsg-remote"
  resource_group_name = azurerm_resource_group.this_rg.name

  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = local.winrms_port
    direction                  = "Inbound"
    name                       = "WinRMs"
    priority                   = 151
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }
  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = "22"
    direction                  = "Inbound"
    name                       = "SSH"
    priority                   = 152
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }
}

/* Uncomment this section if you would like to include a bastion resource with this example.
resource "azurerm_public_ip" "bastionpip" {
  name                = module.naming.public_ip.name_unique
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = module.naming.bastion_host.name_unique
  location            = azurerm_resource_group.this_rg.location
  resource_group_name = azurerm_resource_group.this_rg.name

  ip_configuration {
    name                 = "${module.naming.bastion_host.name_unique}-ipconf"
    subnet_id            = module.vnet.subnets["AzureBastionSubnet"].resource_id
    public_ip_address_id = azurerm_public_ip.bastionpip.id
  }
}
*/


data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.this_rg.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this_rg.name
  tags                = local.tags
}

module "avm_res_keyvault_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "=0.10.0"

  location               = azurerm_resource_group.this_rg.location
  name                   = "${module.naming.key_vault.name_unique}-win-rac"
  resource_group_name    = azurerm_resource_group.this_rg.name
  tenant_id              = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment = true # Required to deploy the certificates to the VM
  network_acls = {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
  role_assignments = {
    deployment_user_certificates = {
      # give the deployment user access to certificates
      role_definition_id_or_name = "Key Vault Certificates Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
    deployment_user_secrets = {
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }

    user_managed_identity_certificates = {
      role_definition_id_or_name = "Key Vault Certificate User"
      principal_id               = azurerm_user_assigned_identity.this.principal_id
      principal_type             = "ServicePrincipal"
    }

    user_managed_identity_secrets = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = azurerm_user_assigned_identity.this.principal_id
      principal_type             = "ServicePrincipal"
    }
  }
  tags = local.tags
  wait_for_rbac_before_secret_operations = {
    create = "60s"
  }
}

resource "random_string" "public_ip_fqdn" {
  length  = 8
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_public_ip" "this" {
  allocation_method       = "Static"
  location                = azurerm_resource_group.this_rg.location
  name                    = module.naming.public_ip.name_unique
  resource_group_name     = azurerm_resource_group.this_rg.name
  domain_name_label       = random_string.public_ip_fqdn.result
  idle_timeout_in_minutes = 30
  ip_version              = "IPv4"
  sku                     = "Standard"
  sku_tier                = "Regional"
  zones                   = ["1", "2", "3"]
}


# For production deployment, use a different keyvault for the winrm certificate from the password
resource "azurerm_key_vault_certificate" "self_signed_winrm" {
  key_vault_id = module.avm_res_keyvault_vault.resource_id
  name         = try(format("%s-winrms-cert", module.naming.virtual_machine.name_unique))
  tags         = local.tags

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    key_properties {
      exportable = true
      key_type   = "RSA"
      reuse_key  = true
      key_size   = 4096
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }
    x509_certificate_properties {
      key_usage = [
        "digitalSignature",
        "keyAgreement",
        "keyEncipherment",
      ]
      subject            = format("CN=%s", module.naming.virtual_machine.name_unique)
      validity_in_months = 12
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      subject_alternative_names {
        dns_names = flatten([
          # format("%s.%s", coalesce(var.computer_name, var.name), nic.internal_domain_name_suffix)
          module.naming.virtual_machine.name_unique,
          azurerm_public_ip.this.ip_address,
          azurerm_public_ip.this.fqdn
        ])
      }
    }
  }

  depends_on = [module.avm_res_keyvault_vault]
}

module "testvm" {
  source = "../../"

  location = azurerm_resource_group.this_rg.location
  name     = module.naming.virtual_machine.name_unique
  network_interfaces = {
    network_interface_1 = {
      name = module.naming.network_interface.name_unique
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "${module.naming.network_interface.name_unique}-ipconfig1"
          private_ip_subnet_resource_id = module.vnet.subnets["vm_subnet_1"].resource_id
          public_ip_address_resource_id = azurerm_public_ip.this.id
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
  # custom_data got injected in the vm at c:\AzureData\CustomData.bin
  custom_data = base64encode(<<-CD
  # Enable WinRM HTTPS listener
  Enable-PSRemoting -Force

  Get-ChildItem wsman:\localhost\Listener\ | Where-Object -Property Keys -like 'Transport=HTTP*' | Remove-Item -Recurse
  $certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -match "CN=${module.naming.virtual_machine.name_unique}"}
  New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -Port ${local.winrms_port} -CertificateThumbprint $certificate.thumbprint -Force

  # Allow HTTPS traffic in the Windows firewall
  New-NetFirewallRule -DisplayName "Allow WinRM HTTPS" -Direction Inbound -LocalPort ${local.winrms_port} -Protocol TCP -Action Allow -Verbose

  # Set HTTPS listener to be the default listener
  winrm set winrm/config/service/Auth '@{Certificate="true"}'
  winrm set winrm/config/service '@{AllowUnencrypted="false"}'

  # Restart WinRM service
  Restart-Service WinRM -Force
  # Display for logs
  WinRM e winrm/config/listener
  CD
  )
  enable_telemetry = var.enable_telemetry
  extensions = {
    install_winrms = {
      name                        = "install_winrms"
      failure_suppression_enabled = false
      publisher                   = "Microsoft.Compute"
      type                        = "CustomScriptExtension"
      type_handler_version        = "1.10"

      settings = jsonencode(
        {
          commandToExecute = "copy c:\\AzureData\\CustomData.bin c:\\AzureData\\winrms.ps1 && powershell.exe -ExecutionPolicy Unrestricted -File c:\\AzureData\\winrms.ps1 > C:\\AzureData\\winrms.log"
        }
      )

    }
    openssh_windows = {
      name                        = "WindowsOpenSSH"
      failure_suppression_enabled = true
      publisher                   = "Microsoft.Azure.OpenSSH"
      type                        = "WindowsOpenSSH"
      type_handler_version        = "3.0"
    }
    keyvault_extension = {
      name                       = "KVVMExtension"
      publisher                  = "Microsoft.Azure.KeyVault"
      type                       = lower(local.os_type) == "windows" ? "KeyVaultForWindows" : "KeyVaultForLinux"
      type_handler_version       = lower(local.os_type) == "windows" ? "3.0" : "2.0"
      auto_upgrade_minor_version = true
      settings = jsonencode(
        {
          secretsManagementSettings = {
            pollingIntervalInS = "60"                                              #"3600"
            linkOnRenewal      = lower(local.os_type) == "windows" ? false : false # always false on Linux.
            requireInitialSync = true                                              # requires user msi https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/key-vault-linux#extension-dependency-ordering
            observedCertificates = [
              {
                url                      = azurerm_key_vault_certificate.self_signed_winrm.versionless_secret_id
                certificateStoreName     = lower(local.os_type) == "windows" ? "MY" : null
                certificateStoreLocation = lower(local.os_type) == "windows" ? "LocalMachine" : "/var/lib/waagent/Microsoft.Azure.KeyVault"
              }
            ]
          }
          authenticationSettings = {
            msiEndpoint = "http://169.254.169.254/metadata/identity/oauth2/token"
            msiClientId = azurerm_user_assigned_identity.this.client_id
          }
        }
      )
      # Troubleshooting logs - https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/key-vault-windows?tabs=version3#review-logs-and-configuration
      # more
    }
  }
  managed_identities = {
    user_assigned_resource_ids = [azurerm_user_assigned_identity.this.id]
  }
  os_type = local.os_type
  # Install the certiciate for WinRMs in the computer certificate store
  secrets = [
    {
      key_vault_id = module.avm_res_keyvault_vault.resource_id
      certificate = [
        {
          url   = azurerm_key_vault_certificate.self_signed_winrm.secret_id
          store = "My"
        }
      ]
    }
  ]
  sku_size = module.vm_sku.sku
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
  tags = local.tags
  winrm_listeners = [
    {
      protocol        = "Https"
      certificate_url = azurerm_key_vault_certificate.self_signed_winrm.secret_id
    },
    # {
    #   protocol = "Http"
    # }
  ]

  depends_on = [module.avm_res_keyvault_vault]
}

resource "terraform_data" "enable_certificate_rotation_on_winrms_listener" {
  triggers_replace = sha512(jsonencode([
    azurerm_key_vault_certificate.self_signed_winrm.versionless_secret_id,
    local.admin_username,
    local.inline_remote_exec,
    local.winrms_port,
    module.testvm.virtual_machine_azurerm.virtual_machine_id,
    sensitive(module.testvm.admin_password)
  ]))

  connection {
    host     = azurerm_public_ip.this.ip_address
    https    = true
    insecure = true # Using a self-signed certificate
    password = module.testvm.admin_password
    port     = local.winrms_port
    type     = "winrm"
    user     = local.admin_username
    use_ntlm = true
  }

  provisioner "file" {
    source      = "w_sc_task_rotate_winrms_cert.ps1"
    destination = "C:\\AzureData\\w_sc_task_rotate_winrms_cert.ps1"
  }

  provisioner "remote-exec" {
    inline = local.inline_remote_exec
  }

  depends_on = [module.testvm]
}

resource "terraform_data" "test_connection_ssh" {
  triggers_replace = sha512(jsonencode([
    azurerm_key_vault_certificate.self_signed_winrm.versionless_secret_id,
    local.admin_username,
    local.winrms_port,
    module.testvm.admin_password,
    module.testvm.virtual_machine_azurerm.virtual_machine_id
  ]))

  connection {
    agent           = false # for windows
    host            = azurerm_public_ip.this.ip_address
    password        = module.testvm.admin_password
    port            = 22
    target_platform = "windows"
    type            = "ssh"
    user            = local.admin_username
  }

  provisioner "remote-exec" {
    inline = [
      "ipconfig /all"
    ]
  }

  depends_on = [module.testvm]
}
