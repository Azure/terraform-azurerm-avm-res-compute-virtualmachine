# This is required for most resource modules
variable "resource_group" {
  type        = string
  description = "The resource group name of the resource group where the vm resources will be deployed."
  nullable    = false
}

variable "virtualmachine_os_type" {
  type        = string
  description = "The base OS type of the vm to be built.  Valid answers are Windows or Linux"
  nullable    = false
  default     = "Windows"
}

variable "virtualmachine_name" {
  type        = string
  description = "The name to use when creating the virtual machine."
  nullable    = false
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to be assigned to this resource"
}

variable "admin_username" {
  type        = string
  description = "Name to use for the default admin account created for the virtual machine"
  default     = "azureuser"
  nullable    = false
}

variable "virtualmachine_sku_size" {
  type        = string
  description = "The sku value to use for this virtual machine"
  default     = "Standard_D2as_v4"
  nullable    = false
}

variable "admin_credential_key_vault_resource_id" {
  type        = string
  description = "The Azure resource ID for the key vault that stores admin credential information"
  nullable    = false
}

variable "disable_password_authentication" {
  type        = bool
  description = "If true this value will disallow password authentication on linux vm's. This will require at least one public key to be configured."
  default     = true
}

variable "generate_admin_password_or_ssh_key" {
  type        = bool
  description = "Set this value to true if the deployment should create a strong password for the admin user."
  default     = true
}

variable "admin_password_key_vault_secret_name" {
  type        = string
  description = "The name of the key vault secret which should be used for the admin password"
  default     = ""
}

variable "admin_ssh_keys" {
  type = list(object({
    public_key = string
    username   = string
  }))
  default     = []
  description = <<-EOT
  set(object({
    public_key = "(Required) The Public Key which should be used for authentication, which needs to be at least 2048-bit and in `ssh-rsa` format. Changing this forces a new resource to be created."
    username   = "(Required) The Username for which this Public SSH Key should be configured. Changing this forces a new resource to be created. The Azure VM Agent only allows creating SSH Keys at the path `/home/{admin_username}/.ssh/authorized_keys` - as such this public key will be written to the authorized keys file. If no username is provided this module will use var.admin_username."
  }))
  EOT
}

variable "additional_unattend_contents" {
  type = list(object({
    content = string
    setting = string
  }))
  default     = []
  description = <<-EOT
  list(object({
    content = "(Required) The XML formatted content that is added to the unattend.xml file for the specified path and component. Changing this forces a new resource to be created."
    setting = "(Required) The name of the setting to which the content applies. Possible values are `AutoLogon` and `FirstLogonCommands`. Changing this forces a new resource to be created."
  }))
  EOT
}

variable "allow_extension_operations" {
  type        = bool
  default     = false
  description = "(Optional) Should Extension Operations be allowed on this Virtual Machine? Defaults to `false`."
}

variable "enable_automatic_updates" {
  type        = bool
  default     = true
  description = "(Optional) Specifies if Automatic Updates are Enabled for the Windows Virtual Machine. Changing this forces a new resource to be created. Defaults to `true`."
}

variable "availability_set_resource_id" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Azure Resource ID of the Availability Set in which the Virtual Machine should exist. Cannot be used along with `new_availability_set`, `new_capacity_reservation_group`, `capacity_reservation_group_id`, `virtual_machine_scale_set_id`, `zone`. Changing this forces a new resource to be created."
}

variable "boot_diagnostics" {
  type        = bool
  default     = false
  description = "(Optional) Enable or Disable boot diagnostics."
  nullable    = false
}

variable "boot_diagnostics_storage_account_uri" {
  type        = string
  default     = null
  description = "(Optional) The Primary/Secondary Endpoint for the Azure Storage Account which should be used to store Boot Diagnostics, including Console Output and Screenshots from the Hypervisor. Passing a null value will Utilize a managed storage account for diags."
}

variable "bypass_platform_safety_checks_on_user_schedule_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Specifies whether to skip platform scheduled patching when a user schedule is associated with the VM. This value can only be set to true when patch_mode is set to AutomaticByPlatform"
}

variable "capacity_reservation_group_resource_id" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Azure Resource ID of the Capacity Reservation Group with the Virtual Machine should be allocated to. Cannot be used with availability_set_id or proximity_placement_group_id"
}

variable "computer_name" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Hostname which should be used for this Virtual Machine. If unspecified this defaults to the value for the `vm_name` field. If the value of the `vm_name` field is not a valid `computer_name`, then you must specify `computer_name`. Changing this forces a new resource to be created."
}

variable "custom_data" {
  type        = string
  default     = null
  description = "(Optional) The Base64 encoded Custom Data for building this virtual machine. Changing this forces a new resource to be created"

  validation {
    condition     = var.custom_data == null ? true : can(base64decode(var.custom_data))
    error_message = "The `custom_data` must be either `null` or a valid Base64-Encoded string."
  }
}

variable "dedicated_host_resource_id" {
  type = string
  default = null
  description = "(Optional) The Azure Resource ID of the dedicated host where this virtual machine should run. Conflicts with dedicated_host_group_resource_id (dedicated_host_group_id on the azurerm provider)"
  
}

variable "dedicated_host_group_resource_id" {
  type = string
  default = null
  description = "(Optional) The Azure Resource ID of the dedicated host group where this virtual machine should run. Conflicts with dedicated_host_resource_id (dedicated_host_group_id on the azurerm provider)"
  
}

variable "edge_zone" {
  type = string
  default = null
  description = "(Optional) Specifies the Edge Zone within the Azure Region where this Virtual Machine should exist. Changing this forces a new Virtual Machine to be created."
}

variable "encryption_at_host_enabled" {
  type = bool
  default = null
  description = "(Optional) Should all of the disks (including the temp disk) attached to this Virtual Machine be encrypted by enabling Encryption at Host?"
}

variable "eviction_policy" {
  type = string
  default = null
  description = "(Optional) Specifies what should happen when the Virtual Machine is evicted for price reasons when using a Spot instance. Possible values are Deallocate and Delete. Changing this forces a new resource to be created. This value can only be set when priority is set to Spot"
}

variable "extensions_time_budget" {
  type        = string
  default     = "PT1H30M"
  description = "(Optional) Specifies the duration allocated for all extensions to start. The time duration should be between 15 minutes and 120 minutes (inclusive) and should be specified in ISO 8601 format. Defaults to 90 minutes (`PT1H30M`)."
}

variable "hotpatching_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Should the VM be patched without requiring a reboot? Possible values are `true` or `false`. Defaults to `false`. For more information about hot patching please see the [product documentation](https://docs.microsoft.com/azure/automanage/automanage-hotpatch). Hotpatching can only be enabled if the `patch_mode` is set to `AutomaticByPlatform`, the `provision_vm_agent` is set to `true`, your `source_image_reference` references a hotpatching enabled image, and the VM's `size` is set to a [Azure generation 2](https://docs.microsoft.com/azure/virtual-machines/generation-2#generation-2-vm-sizes) VM. An example of how to correctly configure a Windows Virtual Machine to use the `hotpatching_enabled` field can be found in the [`./examples/virtual-machines/windows/hotpatching-enabled`](https://github.com/hashicorp/terraform-provider-azurerm/tree/main/examples/virtual-machines/windows/hotpatching-enabled) directory within the GitHub Repository."
}

variable "license_type" {
  type        = string
  default     = null
  description = "(Optional) For Linux virtual machine specifies the BYOL Type for this Virtual Machine, possible values are `RHEL_BYOS` and `SLES_BYOS`. For Windows virtual machine specifies the type of on-premise license (also known as [Azure Hybrid Use Benefit](https://docs.microsoft.com/windows-server/get-started/azure-hybrid-benefit)) which should be used for this Virtual Machine, possible values are `None`, `Windows_Client` and `Windows_Server`."
}

variable "max_bid_price" {
  type        = number
  default     = -1
  description = "(Optional) The maximum price you're willing to pay for this Virtual Machine, in US Dollars; which must be greater than the current spot price. If this bid price falls below the current spot price the Virtual Machine will be evicted using the `eviction_policy`. Defaults to `-1`, which means that the Virtual Machine should not be evicted for price reasons. This can only be configured when `priority` is set to `Spot`."
}

variable "patch_assessment_mode" {
  type        = string
  default     = "ImageDefault"
  description = "(Optional) Specifies the mode of VM Guest Patching for the Virtual Machine. Possible values are `AutomaticByPlatform` or `ImageDefault`. Defaults to `ImageDefault`."
}

variable "patch_mode" {
  type        = string
  default     = null
  description = "(Optional) Specifies the mode of in-guest patching to this Linux Virtual Machine. Possible values are `AutomaticByPlatform` and `ImageDefault`. Defaults to `ImageDefault`. For more information on patch modes please see the [product documentation](https://docs.microsoft.com/azure/virtual-machines/automatic-vm-guest-patching#patch-orchestration-modes)."
}

variable "plan" {
  type = object({
    name      = string
    product   = string
    publisher = string
  })
  default     = null
  description = <<-EOT
  object({
    name      = "(Required) Specifies the Name of the Marketplace Image this Virtual Machine should be created from. Changing this forces a new resource to be created."
    product   = "(Required) Specifies the Product of the Marketplace Image this Virtual Machine should be created from. Changing this forces a new resource to be created."
    publisher = "(Required) Specifies the Publisher of the Marketplace Image this Virtual Machine should be created from. Changing this forces a new resource to be created."
  })
  EOT
}

variable "platform_fault_domain" {
  type = number
  # Why use `null` instead of [`-1`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine#platform_fault_domain) as default value? `platform_fault_domain` must be set along with `virtual_machine_scale_set_id` so the default value must be `null` for this module if we don't want to use `virtual_machine_scale_set_id`.
  default     = null
  description = "(Optional) Specifies the Platform Fault Domain in which this Virtual Machine should be created. Defaults to `null`, which means this will be automatically assigned to a fault domain that best maintains balance across the available fault domains. `virtual_machine_scale_set_id` is required with it. Changing this forces new Virtual Machine to be created."
}

variable "priority" {
  type        = string
  default     = "Regular"
  description = "(Optional) Specifies the priority of this Virtual Machine. Possible values are `Regular` and `Spot`. Defaults to `Regular`. Changing this forces a new resource to be created."
}

variable "provision_vm_agent" {
  type        = bool
  default     = true
  description = "(Optional) Should the Azure VM Agent be provisioned on this Virtual Machine? Defaults to `true`. Changing this forces a new resource to be created. If `provision_vm_agent` is set to `false` then `allow_extension_operations` must also be set to `false`."
}

variable "proximity_placement_group_resource_id" {
  type        = string
  default     = null
  description = "(Optional) The ID of the Proximity Placement Group which the Virtual Machine should be assigned to. Conflicts with `capacity_reservation_group_resource_id`."
}

variable "reboot_setting" {
  type = string
  default = null
  description = "(Optional) Specifies the reboot setting for platform scheduled patching. Possible values are Always, IfRequired and Never. can only be set when patch_mode is set to AutomaticByPlatform"
}


variable "secure_boot_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Specifies whether secure boot should be enabled on the virtual machine. Changing this forces a new resource to be created."
}

variable "termination_notification" {
  type = object({
    enabled = bool
    timeout = optional(string, "PT5M")
  })
  default     = null
  description = <<-EOT
  object({
    enabled = bool
    timeout = optional(string, "PT5M")
  })
  EOT
}

variable "timezone" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Time Zone which should be used by the Virtual Machine, [the possible values are defined here](https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/). Changing this forces a new resource to be created."
}

variable "user_data" {
  type        = string
  default     = null
  description = "(Optional) The Base64-Encoded User Data which should be used for this Virtual Machine."

  validation {
    condition     = var.user_data == null ? true : can(base64decode(var.user_data))
    error_message = "`user_data` must be either `null` or valid base64 encoded string."
  }
}

variable "virtual_machine_scale_set_resource_id" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Orchestrated Virtual Machine Scale Set that this Virtual Machine should be created within. Conflicts with `availability_set_id`. Changing this forces a new resource to be created."
}


variable "vm_additional_capabilities" {
  type = object({
    ultra_ssd_enabled = optional(bool, false)
  })
  default     = null
  description = <<-EOT
  object({
    ultra_ssd_enabled = "(Optional) Should the capacity to enable Data Disks of the `UltraSSD_LRS` storage account type be supported on this Virtual Machine? Defaults to `false`."
  })
  EOT
}

variable "vtpm_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Specifies whether vTPM should be enabled on the virtual machine. Changing this forces a new resource to be created."
}

variable "winrm_listeners" {
  type = set(object({
    protocol        = string
    certificate_url = optional(string)
  }))
  default     = []
  description = <<-EOT
  set(object({
    protocol        = "(Required) Specifies Specifies the protocol of listener. Possible values are `Http` or `Https`"
    certificate_url = "(Optional) The Secret URL of a Key Vault Certificate, which must be specified when `protocol` is set to `Https`. Changing this forces a new resource to be created."
  }))
  EOT
  nullable    = false
}

variable "zone" {
  type        = string
  default     = null
  description = "(Optional) The Availability Zone which the Virtual Machine should be allocated in, only one zone would be accepted. If set then this module won't create `azurerm_availability_set` resource. Changing this forces a new resource to be created."
}

variable "source_image_reference" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default     = null
  description = "The source image to use when building the virtual machine."
}

variable "source_image_resource_id" {
  type        = string
  description = "The Azure resource ID of the source image used to create the VM."
  default     = null
}


##Variables describing the networking configuration
variable "public_ip_configuration_details" {
  type = object({
    allocation_method       = optional(string, "Static")
    zones                   = optional(list(string))
    ddos_protection_mode    = optional(string, "VirtualNetworkInherited")
    ddos_protection_plan_id = optional(string)
    domain_name_label       = optional(string)
    edge_zone               = optional(string)
    idle_timeout_in_minutes = optional(number, 30)
    ip_version              = optional(string, "IPv4")
    sku_tier                = optional(string, "Regional")
    tags                    = optional(map(string))
  })
  default = {
    allocation_method       = "Static"
    ddos_protection_mode    = "VirtualNetworkInherited"
    idle_timeout_in_minutes = 30
    ip_version              = "IPv4"
    sku_tier                = "Regional"
  }
}


variable "network_interfaces" {
  type = list(object({
    name = string
    ip_configurations = list(object({
      name                                                        = string
      private_ip_address                                          = optional(string)
      private_ip_address_version                                  = optional(string, "IPv4")
      private_ip_address_allocation                               = optional(string, "Dynamic")
      private_ip_subnet_resource_id                               = optional(string)
      public_ip_address_resource_id                               = optional(string)
      is_primary_ipconfiguration                                  = optional(bool, true)
      gateway_load_balancer_frontend_ip_configuration_resource_id = optional(string)
      create_public_ip_address                                    = optional(bool, false)
    }))
    dns_servers                    = optional(list(string))
    edge_zone                      = optional(string)
    accelerated_networking_enabled = optional(bool, false)
    ip_forwarding_enabled          = optional(bool, false)
    internal_dns_name_label        = optional(string)
    tags                           = optional(map(string))
  }))
  default = [{
    name = "default-ipv4-ipconfig"
    ip_configurations = [
      {
        name                                                        = "ipv4-ipconfig"
        private_ip_address                                          = null
        private_ip_address_version                                  = "IPv4"
        private_ip_address_allocation                               = "Dynamic"
        private_ip_subnet_resource_id                               = null
        public_ip_address_resource_id                               = null
        is_primary_ipconfiguration                                  = true
        gateway_load_balancer_frontend_ip_configuration_resource_id = null
      }
    ]
    dns_servers                    = null
    edge_zone                      = null
    accelerated_networking_enabled = true
    ip_forwarding_enabled          = false
    internal_dns_name_label        = null
    tags                           = {}
  }]
}

variable "os_disk" {
  type = object({
    caching                          = string
    storage_account_type             = string
    disk_encryption_set_id           = optional(string)
    disk_size_gb                     = optional(number)
    name                             = optional(string)
    secure_vm_disk_encryption_set_id = optional(string)
    security_encryption_type         = optional(string)
    write_accelerator_enabled        = optional(bool, false)
    diff_disk_settings = optional(object({
      option    = string
      placement = optional(string, "CacheDisk")
    }), null)
  })
  nullable = false
  default = {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
}

##Variables describing the data disk configurations
variable "data_disk_managed_disks" {
  type = list(object({
    name                                      = string
    storage_account_type                      = string
    lun                                       = number
    caching                                   = string
    disk_attachment_create_option             = optional(string)
    create_option                             = optional(string, "Empty")
    write_accelerator_enabled                 = optional(bool)
    disk_iops_read_write                      = optional(number)
    disk_mbps_read_write                      = optional(number)
    disk_iops_read_only                       = optional(number)
    disk_mbps_read_only                       = optional(number)
    upload_size_bytes                         = optional(number)
    disk_size_gb                              = optional(number, 128)
    edge_zone                                 = optional(string)
    hyper_v_generation                        = optional(string)
    image_reference_resource_id               = optional(string)
    gallery_image_reference_resource_id       = optional(string)
    logical_sector_size                       = optional(number, 4096)
    optimized_frequent_attach_enabled         = optional(bool, false)
    performance_plus_enabled                  = optional(bool, false)
    os_type                                   = optional(string)
    source_resource_id                        = optional(string)
    source_uri                                = optional(string)
    storage_account_resource_id               = optional(string)
    tier                                      = optional(string)
    max_shares                                = optional(number)
    trusted_launch_enabled                    = optional(bool)
    security_type                             = optional(string)
    secure_vm_disk_encryption_set_resource_id = optional(string)
    on_demand_bursting_enabled                = optional(bool)
    tags                                      = optional(map(string))
    zone                                      = optional(string)
    network_access_policy                     = optional(string)
    disk_access_resource_id                   = optional(string)
    public_network_access_enabled             = optional(bool)
    encryption_settings = optional(list(object({
      disk_encryption_key_vault_secret_url  = optional(string)
      disk_encryption_key_vault_resource_id = optional(string)
      key_encryption_key_vault_secret_url   = optional(string)
      key_encryption_key_vault_resource_id  = optional(string)
    })), [])
    #disk_encryption_set_resource_id = optional(string) #this is currently a preview feature in the provider 
  }))

  default = []
}

variable "extensions" {
  type = set(object({
    name                        = string
    publisher                   = string
    type                        = string
    type_handler_version        = string
    auto_upgrade_minor_version  = optional(bool)
    automatic_upgrade_enabled   = optional(bool)
    failure_suppression_enabled = optional(bool, false)
    settings                    = optional(string)
    protected_settings          = optional(string)
    protected_settings_from_key_vault = optional(object({
      secret_url      = string
      source_vault_id = string
    }))
  }))
  # tflint-ignore: terraform_sensitive_variable_no_default
  default     = []
  description = "Argument to create `azurerm_virtual_machine_extension` resource, the argument descriptions could be found at [the document](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension)."
  nullable    = false
  sensitive   = true # Because `protected_settings` is sensitive

  validation {
    condition = length(var.extensions) == length(distinct([
      for e in var.extensions : e.type
    ]))
    error_message = "`type` in `vm_extensions` must be unique."
  }
}

variable "identity" {
  type = object({
    type         = string
    identity_ids = optional(set(string))
  })
  default     = {
    type = "SystemAssigned"
  }
  description = <<-EOT
  object({
    type         = "(Required) Specifies the type of Managed Service Identity that should be configured on this Linux Virtual Machine. Possible values are `SystemAssigned`, `UserAssigned`, `SystemAssigned, UserAssigned` (to enable both)."
    identity_ids = "(Optional) Specifies a list of User Assigned Managed Identity IDs to be assigned to this Linux Virtual Machine. This is required when `type` is set to `UserAssigned` or `SystemAssigned, UserAssigned`."
  })
  EOT
}

variable "gallery_application" {
  type = list(object({
    version_id             = string
    configuration_blob_uri = optional(string)
    order                  = optional(number, 0)
    tag                    = optional(string)
  }))
  default     = []
  description = <<-EOT
  list(object({
    version_id             = "(Required) Specifies the Gallery Application Version resource ID."
    configuration_blob_uri = "(Optional) Specifies the URI to an Azure Blob that will replace the default configuration for the package if provided."
    order                  = "(Optional) Specifies the order in which the packages have to be installed. Possible values are between `0` and `2,147,483,647`."
    tag                    = "(Optional) Specifies a passthrough value for more generic context. This field can be any valid `string` value."
  }))
  EOT
}

variable "secrets" {
  type = list(object({
    key_vault_id = string
    certificate = set(object({
      url   = string
      store = optional(string)
    }))
  }))
  default     = []
  description = <<-EOT
  list(object({
    key_vault_id = "(Required) The ID of the Key Vault from which all Secrets should be sourced."
    certificate  = set(object({
      url   = "(Required) The Secret URL of a Key Vault Certificate. This can be sourced from the `secret_id` field within the `azurerm_key_vault_certificate` Resource."
      store = "(Optional) The certificate store on the Virtual Machine where the certificate should be added. Required when use with Windows Virtual Machine."
    }))
  }))
  EOT
  nullable    = false
}



variable "append_name_string_suffix" {
  type        = bool
  description = "Disable this to remove the partial hash value used to ensure sub-resource naming uniqueness"
  default     = true
}

variable "name_string_suffix_length" {
  type        = number
  description = "The length of the partial hash value to include in the name string"
  default     = 6
}


/*
variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetry.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}*/

