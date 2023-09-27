# This is required for most resource modules
variable "admin_username" {
  type        = string
  description = "Name to use for the default admin account created for the virtual machine"
  default     = "azureuser"
  nullable    = false
  validation {
    condition     = !can(regex("^(administrator|admin|user|user1|test|user2|test2|user3|admin1|1|123|a|actuser|adm|admin2|aspnet|backup|console|david|guest|john|owner|root|server|sql|support|support_388945a0|sys|test2|test3|user4|user5)$", lower(var.admin_username)))
    error_message = "Admin username may not contain any of the following reserved values. ( administrator, admin, user, user1, test, user2, test1, user3, admin1, 1, 123, a, actuser, adm, admin2, aspnet, backup, console, david, guest, john, owner, root, server, sql, support, support_388945a0, sys, test2, test3, user4, user5 )"
  }
  validation {
    condition     = can(regex("^.{1,64}$", var.admin_username))
    error_message = "Admin username for linux must be between 1 and 64 characters in length. Admin name for windows must be between 1 and 20 characters in length."
  }
}

variable "location" {
  type        = string
  description = "The Azure region where this and supporting resources should be deployed.  Defaults to the Resource Groups location if undefined."
  default     = null
}

variable "resource_group" {
  type        = string
  description = "The resource group name of the resource group where the vm resources will be deployed."
  nullable    = false
}

variable "virtualmachine_name" {
  type        = string
  description = "The name to use when creating the virtual machine."
  nullable    = false
  validation {
    condition     = can(regex("^.{1,64}$", var.virtualmachine_name))
    error_message = "virtual machine names for linux must be between 1 and 64 characters in length. Admin name for windows must be between 1 and 20 characters in length."
  }
}

variable "virtualmachine_os_type" {
  type        = string
  description = "The base OS type of the vm to be built.  Valid answers are Windows or Linux"
  nullable    = false
  default     = "Windows"
  validation {
    condition     = can(regex("^(windows|linux)$", lower(var.virtualmachine_os_type)))
    error_message = "Valid OS type values are Windows or Linux."
  }
}

variable "virtualmachine_sku_size" {
  type        = string
  description = "The sku value to use for this virtual machine"
  default     = "Standard_D2as_v4"
  nullable    = false
}

variable "lock" {
  type = object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
  description = <<LOCK
    "The lock level to apply to this virtual machine and all of it's child resources. The default value is none. Possible values are `None`, `CanNotDelete`, and `ReadOnly`. Set the lock value on child resource values explicitly to override any inherited locks." 

    Example Inputs:
    ```terraform
    lock = {
      name = "lock-{resourcename}" # optional
      type = "CanNotDelete" 
    }
    ```
    LOCK
  default     = {}
  nullable    = false
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly", "None"], var.lock.kind)
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}

#potential future functionality.  Ignore for now
variable "inherit_tags" {
  type        = bool
  default     = false
  description = "Apply tags from the resource group to resources in the module that support tags.  Set this to false to disable the merging of the resource group tags. This is future functionality and can currently be ignored."
}

variable "tags" {
  type        = map(any)
  default     = {}
  description = "Map of tags to be assigned to this resource"
}

#Identity related variables
variable "admin_credential_key_vault_resource_id" {
  type        = string
  description = "The Azure resource ID for the key vault that stores admin credential information"
}

variable "admin_password" {
  type        = string
  description = "Password to use for the default admin account created for the virtual machine"
  default     = null
  sensitive   = true
}

variable "admin_password_key_vault_secret_name" {
  type        = string
  description = "The name of the key vault secret which should be used for the admin password"
  default     = null
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

variable "admin_ssh_keys" {
  type = list(object({
    public_key = string
    username   = string
  }))
  default     = []
  description = <<ADMIN_SSH_KEYS
  list(object({
    public_key = "(Required) The Public Key which should be used for authentication, which needs to be at least 2048-bit and in `ssh-rsa` format. Changing this forces a new resource to be created."
    username   = "(Required) The Username for which this Public SSH Key should be configured. Changing this forces a new resource to be created. The Azure VM Agent only allows creating SSH Keys at the path `/home/{admin_username}/.ssh/authorized_keys` - as such this public key will be written to the authorized keys file. If no username is provided this module will use var.admin_username."
  }))

  Example Input:

  ```terraform
  admin_ssh_keys = [
    {
      public_key = "<base64 string for the key>"
      username   = "exampleuser"
    },
    {
      public_key = "<base64 string for the next user key>"
      username   = "examleuser2"
    }
  ]
  ```
  ADMIN_SSH_KEYS
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<IDENTITY
  Sets the managed identity configuration for the virtual machine being deployed. Be aware that capabilities such as the Azure Monitor Agent and Role Assignments require that a managed identity has been configured.
  object({
    system_assigned = "(Optional) Specifies whether the System Assigned Managed Identity should be enabled.  Defaults to false. 
   user_assigned_resource_ids    = "(Optional) Specifies a list of User Assigned Managed Identity IDs to be assigned to this Virtual Machine."
  })

  Example Inputs:

  ```terraform
  #default system managed identity
  managed_identities = {
   system_assigned = true
  }
  #user assigned managed identity only
  managed_identities           = {
    user_assigned_resource_ids = ["<azure resource ID of a user assigned managed identity>]
  }
  #user assigned and system assigned managed identities
  identity = {
    system_assigned            = true
    user_assigned_resource_ids = ["<azure resource ID of a user assigned managed identity>]
  }
  ```
  IDENTITY
}


##variables describing the disks and imaging details
variable "source_image_reference" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default     = null
  description = <<SOURCE_IMAGE_REFERENCE
    The source image to use when building the virtual machine. Either source_image_resource_id or source_image_reference must be set and both can not be null at the same time."
    object({
      publisher = "(Required) Specifies the publisher of the image this virtual machine should be created from.  Changing this forces a new virtual machine to be created.
      offer     = "(Required) Specifies the offer of the image used to create this virtual machine.  Changing this forces a new virtual machine to be created.
      sku       = "(Required) Specifies the sku of the image used to create this virutal machine.  Changing this forces a new virtual machine to be created.
      version   = "(Required) Specifies the version of the image used to create this virutal machine.  Changing this forces a new virtual machine to be created.
    })

  Example Inputs:

  ```terraform
  #Linux example:
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  #Windows example:
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  ```
  SOURCE_IMAGE_REFERENCE

}

variable "source_image_resource_id" {
  type        = string
  description = "The Azure resource ID of the source image used to create the VM. Either source_image_resource_id or source_image_reference must be set and both can not be null at the same time."
  default     = null
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

  description = <<OS_DISK
  Configuration values for the OS disk on the virtual machine
    object({
      caching                          = (Required) - The type of caching which should be used for the internal OS disk.  Possible values are `None`, `ReadOnly`, and `ReadWrite`.
      storage_account_type             = (Required) - The Type of Storage Account which should back this the Internal OS Disk. Possible values are `Standard_LRS`, `StandardSSD_LRS`, `Premium_LRS`, `StandardSSD_ZRS` and `Premium_ZRS`. Changing this forces a new resource to be created
      disk_encryption_set_id           = (Optional) - The Azure Resource ID of the Disk Encryption Set which should be used to Encrypt this OS Disk. Conflicts with secure_vm_disk_encryption_set_id. The Disk Encryption Set must have the Reader Role Assignment scoped on the Key Vault - in addition to an Access Policy to the Key Vault
      disk_size_gb                     = (Optional) - The Size of the Internal OS Disk in GB, if you wish to vary from the size used in the image this Virtual Machine is sourced from.
      name                             = (Optional) - The name which should be used for the Internal OS Disk. Changing this forces a new resource to be created.
      secure_vm_disk_encryption_set_id = (Optional) - The Azure Resource ID of the Disk Encryption Set which should be used to Encrypt this OS Disk when the Virtual Machine is a Confidential VM. Conflicts with disk_encryption_set_id. Changing this forces a new resource to be created.
      security_encryption_type         = (Optional) - Encryption Type when the Virtual Machine is a Confidential VM. Possible values are `VMGuestStateOnly` and `DiskWithVMGuestState`. Changing this forces a new resource to be created. `vtpm_enabled` must be set to true when security_encryption_type is specified. encryption_at_host_enabled cannot be set to `true` when security_encryption_type is set to `DiskWithVMGuestState`
      write_accelerator_enabled        = (Optional) - Should Write Accelerator be Enabled for this OS Disk? Defaults to `false`. This requires that the storage_account_type is set to `Premium_LRS` and that caching is set to `None`
      diff_disk_settings = optional(object({
        option    = (Required) - Specifies the Ephemeral Disk Settings for the OS Disk. At this time the only possible value is `Local`. Changing this forces a new resource to be created.
        placement = (Optional) - Specifies where to store the Ephemeral Disk. Possible values are CacheDisk and ResourceDisk. Defaults to CacheDisk. Changing this forces a new resource to be created.
      }), null)                  
    })
  
  Example Inputs:

  ```terraform
  #basic example:
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  #increased disk size and write acceleration example
  {
    name                      = "sample os disk"
    caching                   = "None"
    storage_account_type      = "Premium_LRS"
    disk_size_gb              = 128
    write_accelerator_enabled = true
  }
  ```
  OS_DISK  
}

##Variables describing the data disk configurations
variable "data_disk_managed_disks" {
  type = list(object({
    name                                      = string
    storage_account_type                      = string
    lun                                       = number
    caching                                   = string
    create_option                             = optional(string, "Empty")
    disk_attachment_create_option             = optional(string)
    write_accelerator_enabled                 = optional(bool)
    disk_iops_read_write                      = optional(number, null)
    disk_mbps_read_write                      = optional(number, null)
    disk_iops_read_only                       = optional(number, null)
    disk_mbps_read_only                       = optional(number, null)
    upload_size_bytes                         = optional(number, null)
    disk_size_gb                              = optional(number, 128)
    edge_zone                                 = optional(string)
    hyper_v_generation                        = optional(string)
    image_reference_resource_id               = optional(string)
    gallery_image_reference_resource_id       = optional(string)
    logical_sector_size                       = optional(number, null)
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
    tags                                      = optional(map(any))
    inherit_tags                              = optional(bool, true)
    zone                                      = optional(string)
    network_access_policy                     = optional(string)
    disk_access_resource_id                   = optional(string)
    public_network_access_enabled             = optional(bool)
    lock                                      = optional(string)
    lock_name_suffix                          = optional(string, "lock")
    encryption_settings = optional(list(object({
      disk_encryption_key_vault_secret_url  = optional(string)
      disk_encryption_key_vault_resource_id = optional(string)
      key_encryption_key_vault_secret_url   = optional(string)
      key_encryption_key_vault_resource_id  = optional(string)
    })), [])
    #disk_encryption_set_resource_id = optional(string) #this is currently a preview feature in the provider 
  }))
  default     = []
  description = <<DATA_DISK_MANAGED_DISKS
  This variable is used to define one or more data disks for creation and attachment to the virtual machine. 
    list(object({
    name                                      = (Required) - Specifies the name of the Managed Disk. Changing this forces a new resource to be created.
    storage_account_type                      = (Required) - The type of storage to use for the managed disk. Possible values are Standard_LRS, StandardSSD_ZRS, Premium_LRS, PremiumV2_LRS, Premium_ZRS, StandardSSD_LRS or UltraSSD_LRS
    lun                                       = (Required) - The Logical Unit Number of the Data Disk, which needs to be unique within the Virtual Machine. Changing this forces a new resource to be created.
    caching                                   = (Required) - Specifies the caching requirements for this Data Disk. Possible values include None, ReadOnly and ReadWrite
    create_option                             = (Required) - The method to use when creating the managed disk. Changing this forces a new resource to be created. Possible values include: 1. Import - Import a VHD file in to the managed disk (VHD specified with source_uri). 2.ImportSecure - Securely import a VHD file in to the managed disk (VHD specified with source_uri). 3. Empty - Create an empty managed disk. 4. Copy - Copy an existing managed disk or snapshot (specified with source_resource_id). 5. FromImage - Copy a Platform Image (specified with image_reference_id) 6. Restore - Set by Azure Backup or Site Recovery on a restored disk (specified with source_resource_id). 7. Upload - Upload a VHD disk with the help of SAS URL (to be used with upload_size_bytes).
    disk_attachment_create_option             = (Optional) - The disk attachment create Option of the Data Disk, such as Empty or Attach. Defaults to Attach. Changing this forces a new resource to be created.    
    write_accelerator_enabled                 = (Optional) - Specifies if Write Accelerator is enabled on the disk. This can only be enabled on Premium_LRS managed disks with no caching and M-Series VMs. Defaults to false.
    disk_iops_read_write                      = (Optional) - The number of IOPS allowed for this disk; only settable for UltraSSD disks and PremiumV2 disks. One operation can transfer between 4k and 256k bytes.
    disk_mbps_read_write                      = (Optional) - The bandwidth allowed for this disk; only settable for UltraSSD disks and PremiumV2 disks. MBps means millions of bytes per second.
    disk_iops_read_only                       = (Optional) - The number of IOPS allowed across all VMs mounting the shared disk as read-only; only settable for UltraSSD disks and PremiumV2 disks with shared disk enabled. One operation can transfer between 4k and 256k bytes.
    disk_mbps_read_only                       = (Optional) - The bandwidth allowed across all VMs mounting the shared disk as read-only; only settable for UltraSSD disks and PremiumV2 disks with shared disk enabled. MBps means millions of bytes per second.
    upload_size_bytes                         = (Optional) - Specifies the size of the managed disk to create in bytes. Required when create_option is Upload. The value must be equal to the source disk to be copied in bytes. Source disk size could be calculated with ls -l or wc -c. More information can be found at Copy a managed disk. Changing this forces a new resource to be created.
    disk_size_gb                              = (Optional, Required for a new managed disk) - Specifies the size of the managed disk to create in gigabytes. If create_option is Copy or FromImage, then the value must be equal to or greater than the source's size. The size can only be increased.If No Downtime Resizing is not available, be aware that changing this value is disruptive if the disk is attached to a Virtual Machine. The VM will be shut down and de-allocated as required by Azure to action the change. Terraform will attempt to start the machine again after the update if it was in a running state when the apply was started. When upgrading disk_size_gb from value less than 4095 to a value greater than 4095, the disk will be detached from its associated Virtual Machine as required by Azure to action the change. Terraform will attempt to reattach the disk again after the update.
    edge_zone                                 = (Optional) - Specifies the Edge Zone within the Azure Region where this Managed Disk should exist. Changing this forces a new Managed Disk to be created.
    hyper_v_generation                        = (Optional) - The HyperV Generation of the Disk when the source of an Import or Copy operation targets a source that contains an operating system. Possible values are V1 and V2. For ImportSecure it must be set to V2. Changing this forces a new resource to be created.
    image_reference_resource_id               = (Optional) - ID of an existing platform/marketplace disk image to copy when create_option is FromImage. This field cannot be specified if gallery_image_reference_resource_id is specified. Changing this forces a new resource to be created.
    gallery_image_reference_resource_id       = (Optional) - ID of a Gallery Image Version to copy when create_option is FromImage. This field cannot be specified if image_reference_id is specified. Changing this forces a new resource to be created.
    logical_sector_size                       = (Optional) - Logical Sector Size. Possible values are: 512 and 4096. Defaults to 4096. Changing this forces a new resource to be created. Setting logical sector size is supported only with UltraSSD_LRS disks and PremiumV2_LRS disks.
    optimized_frequent_attach_enabled         = (Optional) - Specifies whether this Managed Disk should be optimized for frequent disk attachments (where a disk is attached/detached more than 5 times in a day). Defaults to false. Setting optimized_frequent_attach_enabled to true causes the disks to not align with the fault domain of the Virtual Machine, which can have operational implications.
    performance_plus_enabled                  = (Optional) - Specifies whether Performance Plus is enabled for this Managed Disk. Defaults to false. Changing this forces a new resource to be created. performance_plus_enabled can only be set to true when using a Managed Disk with an Ultra SSD.
    os_type                                   = (Optional) - Specify a value when the source of an Import, ImportSecure or Copy operation targets a source that contains an operating system. Valid values are Linux or Windows.
    source_resource_id                        = (Optional) - The ID of an existing Managed Disk or Snapshot to copy when create_option is Copy or the recovery point to restore when create_option is Restore. Changing this forces a new resource to be created.
    source_uri                                = (Optional) - URI to a valid VHD file to be used when create_option is Import or ImportSecure. Changing this forces a new resource to be created.
    storage_account_resource_id               = (Optional) - The ID of the Storage Account where the source_uri is located. Required when create_option is set to Import or ImportSecure. Changing this forces a new resource to be created.
    tier                                      = (Optional) - The disk performance tier to use. Possible values are documented at https://docs.microsoft.com/azure/virtual-machines/disks-change-performance. This feature is currently supported only for premium SSDs.Changing this value is disruptive if the disk is attached to a Virtual Machine. The VM will be shut down and de-allocated as required by Azure to action the change. Terraform will attempt to start the machine again after the update if it was in a running state when the apply was started.
    max_shares                                = (Optional) - The maximum number of VMs that can attach to the disk at the same time. Value greater than one indicates a disk that can be mounted on multiple VMs at the same time. Premium SSD maxShares limit: P15 and P20 disks: 2. P30,P40,P50 disks: 5. P60,P70,P80 disks: 10. For ultra disks the max_shares minimum value is 1 and the maximum is 5.
    trusted_launch_enabled                    = (Optional) - Specifies if Trusted Launch is enabled for the Managed Disk. Changing this forces a new resource to be created. Trusted Launch can only be enabled when create_option is FromImage or Import
    security_type                             = (Optional) - Security Type of the Managed Disk when it is used for a Confidential VM. Possible values are ConfidentialVM_VMGuestStateOnlyEncryptedWithPlatformKey, ConfidentialVM_DiskEncryptedWithPlatformKey and ConfidentialVM_DiskEncryptedWithCustomerKey. Changing this forces a new resource to be created. When security_type is set to ConfidentialVM_DiskEncryptedWithCustomerKey the value of create_option must be one of FromImage or ImportSecure. security_type cannot be specified when trusted_launch_enabled is set to true. secure_vm_disk_encryption_set_id must be specified when security_type is set to ConfidentialVM_DiskEncryptedWithCustomerKey.
    secure_vm_disk_encryption_set_resource_id = (Optional) - The ID of the Disk Encryption Set which should be used to Encrypt this OS Disk when the Virtual Machine is a Confidential VM. Conflicts with disk_encryption_set_id. Changing this forces a new resource to be created. secure_vm_disk_encryption_set_resource_id can only be specified when security_type is set to ConfidentialVM_DiskEncryptedWithCustomerKey.
    on_demand_bursting_enabled                = (Optional) - Specifies if On-Demand Bursting is enabled for the Managed Disk.
    tags                                      = (Optional) - A mapping of tags to assign to the resource.
    inherit_tags                              = (Optional) - Defaults to true.  Set this to false if only the tags defined on this resource should be applied.
    zone                                      = (Optional) - Specifies the Availability Zone in which this Managed Disk should be located. Changing this property forces a new resource to be created. Availability Zones are only supported in select regions at this time.
    network_access_policy                     = (Optional) - Policy for accessing the disk via network. Allowed values are AllowAll, AllowPrivate, and DenyAll.
    disk_access_resource_id                   = (Optional) - The ID of the disk access resource for using private endpoints on disks. disk_access_resource_id is only supported when network_access_policy is set to AllowPrivate.
    public_network_access_enabled             = (Optional) - Whether it is allowed to access the disk via public network. Defaults to true.
    lock                                      = (Optional) - Set this value to override the resource level lock value.  Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
    lock_name_suffix                          = (Optional) - The name suffix to append to the nic name for use as the lock name.  Defaults to lock.
    encryption_settings = optional(list(object({
      disk_encryption_key_vault_secret_url  = (Required) - The URL to the Key Vault Secret used as the Disk Encryption Key. This can be found as id on the azurerm_key_vault_secret resource.
      disk_encryption_key_vault_resource_id = (Required) - The ID of the source Key Vault. This can be found as id on the azurerm_key_vault resource.
      key_encryption_key_vault_secret_url   = (Required) - The URL to the Key Vault Key used as the Key Encryption Key. This can be found as id on the azurerm_key_vault_key resource.
      key_encryption_key_vault_resource_id  = (Required) - The ID of the source Key Vault. This can be found as id on the azurerm_key_vault resource.
    })), [])

  Example Inputs:

  ```terraform
  #Create a new empty disk and attach it as lun 0
  data_disk_managed_disks = [
    {
      name                 = "testdisk1-win-lun0"
      storage_account_type = "StandardSSD_LRS"
      lun                  = 0
      caching              = "ReadWrite"
      disk_size_gb         = 32
    }
  ]
  ```
  DATA_DISK_MANAGED_DISKS
}


##Variables describing the networking configuration
#variable configuration values to use when the network interface include the option to create a new public IP address
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
    inherit_tags            = optional(bool, false)
    tags                    = optional(map(any))
    lock                    = optional(string)
    lock_name_suffix        = optional(string, "lock")
  })
  default = {
    allocation_method       = "Static"
    ddos_protection_mode    = "VirtualNetworkInherited"
    idle_timeout_in_minutes = 30
    ip_version              = "IPv4"
    sku_tier                = "Regional"
  }
  description = <<PUBLIC_IP_CONFIGURATION_DETAILS
    allocation_method       = (Required) - Defines the allocation method for this IP address. Possible values are Static or Dynamic.
    zones                   = (Optional) - A collection containing the availability zone to allocate the Public IP in. Changing this forces a new resource to be created.
    ddos_protection_mode    = (Optional) - The DDoS protection mode of the public IP. Possible values are Disabled, Enabled, and VirtualNetworkInherited. Defaults to VirtualNetworkInherited.
    ddos_protection_plan_id = (Optional) - The ID of DDoS protection plan associated with the public IP. ddos_protection_plan_id can only be set when ddos_protection_mode is Enabled
    domain_name_label       = (Optional) - Label for the Domain Name. Will be used to make up the FQDN. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system.
    edge_zone               = (Optional) - Specifies the Edge Zone within the Azure Region where this Public IP should exist. Changing this forces a new Public IP to be created.
    idle_timeout_in_minutes = (Optional) - Specifies the timeout for the TCP idle connection. The value can be set between 4 and 30 minutes.
    ip_version              = (Optional) - The IP Version to use, IPv6 or IPv4. Changing this forces a new resource to be created. Only static IP address allocation is supported for IPv6.
    sku_tier                = (Optional) - The SKU of the Public IP. Accepted values are Basic and Standard. Defaults to Basic. Changing this forces a new resource to be created. When sku_tier is set to Global, sku must be set to Standard.
    tags                    = (Optional) - A mapping of tags to assign to the resource.
    inherit_tags            = (Optional) - Defaults to false.  Set this to false if only the tags defined on this resource should be applied. - Future functionality leaving in.
    lock                    = (Optional) - Set this value to override the resource level lock value.  Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
    lock_name_suffix        = (Optional) - The name suffix to append to the pip name for use as the lock name.  Defaults to lock.

    Example Inputs:

    ```terraform
    #Standard Regional IPV4 Public IP address configuration
    public_ip_configuration_details = {
      allocation_method       = "Static"
      ddos_protection_mode    = "VirtualNetworkInherited"
      idle_timeout_in_minutes = 30
      ip_version              = "IPv4"
      sku_tier                = "Regional"
    }
    ```
  PUBLIC_IP_CONFIGURATION_DETAILS
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
    tags                           = optional(map(any))
    inherit_tags                   = optional(bool, false)
    lock                           = optional(string)
    lock_name_suffix               = optional(string, "lock")
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
  description = <<NETWORK_INTERFACES
    list(object({
    name = (Required) The name of the Network Interface. Changing this forces a new resource to be created.
    ip_configurations = list(object({ 
      name                                                        = (Required) - A name used for this IP Configuration.
      private_ip_address                                          = (Optional) - The Static IP Address which should be used. Configured when private_ip_address_allocation is set to Static 
      private_ip_address_version                                  = (Optional) - The IP Version to use. Possible values are IPv4 or IPv6. Defaults to IPv4.
      private_ip_address_allocation                               = (Required) - The allocation method used for the Private IP Address. Possible values are Dynamic and Static. Dynamic means "An IP is automatically assigned during creation of this Network Interface"; Static means "User supplied IP address will be used"
      private_ip_subnet_resource_id                               = (Optional) - The Azure Resource ID of the Subnet where this Network Interface should be located in.
      public_ip_address_resource_id                               = (Optional) - Reference to a Public IP Address resource ID to associate with this NIC
      is_primary_ipconfiguration                                  = (Optional) - Is this the Primary IP Configuration? Must be true for the first ip_configuration when multiple are specified.
      gateway_load_balancer_frontend_ip_configuration_resource_id = (Optional) - The Frontend IP Configuration Azure Resource ID of a Gateway SKU Load Balancer.)
      create_public_ip_address                                    = (Optional) - Select true here to have the module create the public IP address for this IP Configuration
    }))
    dns_servers                    = (Optional) - A list of IP Addresses defining the DNS Servers which should be used for this Network Interface.
    edge_zone                      = (Optional) - Specifies the Edge Zone within the Azure Region where this Network Interface should exist. Changing this forces a new Network Interface to be created.
    accelerated_networking_enabled = (Optional) - Should Accelerated Networking be enabled? Defaults to false. Only certain Virtual Machine sizes are supported for Accelerated Networking. To use Accelerated Networking in an Availability Set, the Availability Set must be deployed onto an Accelerated Networking enabled cluster.
    ip_forwarding_enabled          = (Optional) - Should IP Forwarding be enabled? Defaults to false
    internal_dns_name_label        = (Optional) - The (relative) DNS Name used for internal communications between Virtual Machines in the same Virtual Network.
    tags                           = (Optional) - A mapping of tags to assign to the resource.
    inherit_tags                   = (Optional) - Defaults to false.  Set this to false if only the tags defined on this resource should be applied. This is potential future functionality and is currently ignored.
    lock                           = (Optional) - Set this value to override the resource level lock value.  Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
    lock_name_suffix               = (Optional) - The name suffix to append to the nic name for use as the lock name.  Defaults to lock.
  }))

  Example Inputs:

  ```terraform
  #Simple private IP single NIC with IPV4 private address
    network_interfaces = [{
      name = "testnic1"
      ip_configurations = [
        {
          name                          = "testnic1-ipconfig"
          private_ip_subnet_resource_id = data.azurerm_subnet.vmsubnet1.id
          create_public_ip_address      = false
        }
      ]
    }
  ]

  #Simple NIC with private and public IP address 
  network_interfaces = [{
      name = "testnic1"
      ip_configurations = [
        {
          name                          = "testnic1-ipconfig"
          private_ip_subnet_resource_id = data.azurerm_subnet.vmsubnet1.id
          create_public_ip_address      = false
        },
        {
          name                          = "testnic1-ipconfig2-public"
          create_public_ip_address      = true
        }
      ]
    }
  ]
  ```
  NETWORK_INTERFACES
}


#General VM settings
variable "additional_unattend_contents" {
  type = list(object({
    content = string
    setting = string
  }))
  default     = []
  description = <<ADDITIONAL_UNATTEND_CONTENTS
  list(object({
    content = "(Required) The XML formatted content that is added to the unattend.xml file for the specified path and component. Changing this forces a new resource to be created."
    setting = "(Required) The name of the setting to which the content applies. Possible values are `AutoLogon` and `FirstLogonCommands`. Changing this forces a new resource to be created."
  }))

  Example Inputs:

  ```terraform
  #Example Reboot
  additional_unattend_contents = [
    {
      content = "<FirstLogonCommands><SynchronousCommand><CommandLine>shutdown /r /t 0 /c \"initial reboot\"</CommandLine><Description>reboot</Description><Order>1</Order></SynchronousCommand></FirstLogonCommands>"
      setting = "FirstLogonCommands"
    }
  ]
  ```
  ADDITIONAL_UNATTEND_CONTENTS  
}

variable "allow_extension_operations" {
  type        = bool
  default     = true
  description = "(Optional) Should Extension Operations be allowed on this Virtual Machine? Defaults to `true`."
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
  type        = string
  default     = null
  description = "(Optional) The Azure Resource ID of the dedicated host where this virtual machine should run. Conflicts with dedicated_host_group_resource_id (dedicated_host_group_id on the azurerm provider)"

}

variable "dedicated_host_group_resource_id" {
  type        = string
  default     = null
  description = "(Optional) The Azure Resource ID of the dedicated host group where this virtual machine should run. Conflicts with dedicated_host_resource_id (dedicated_host_group_id on the azurerm provider)"

}

variable "edge_zone" {
  type        = string
  default     = null
  description = "(Optional) Specifies the Edge Zone within the Azure Region where this Virtual Machine should exist. Changing this forces a new Virtual Machine to be created."
}

variable "encryption_at_host_enabled" {
  type        = bool
  default     = null
  description = "(Optional) Should all of the disks (including the temp disk) attached to this Virtual Machine be encrypted by enabling Encryption at Host?"
}

variable "eviction_policy" {
  type        = string
  default     = null
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
  description = <<PLAN
  Defines the Marketplace image this virtual machine should be creaed from. If you use the plan block with one of Microsoft's marketplace images (e.g. publisher = "MicrosoftWindowsServer"). This may prevent the purchase of the offer. An example Azure API error: The Offer: 'WindowsServer' cannot be purchased by subscription: '12345678-12234-5678-9012-123456789012' as it is not to be sold in market: 'US'. Please choose a subscription which is associated with a different market.
  object({
    name      = "(Required) Specifies the Name of the Marketplace Image this Virtual Machine should be created from. Changing this forces a new resource to be created."
    product   = "(Required) Specifies the Product of the Marketplace Image this Virtual Machine should be created from. Changing this forces a new resource to be created."
    publisher = "(Required) Specifies the Publisher of the Marketplace Image this Virtual Machine should be created from. Changing this forces a new resource to be created."
  })

  Example Input:

  ```terraform
  plan = {
    name      = "17_04_02-payg-essentials"
    product   = "cisco-8000v"
    publisher = "cisco"
  }
  ```
  PLAN
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
  type        = string
  default     = null
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
  description = <<TERMINATION_NOTIFICATION
  object({
    enabled = (Required) - Should the termination notification be enabled on this Virtual Machine?
    timeout = (Optional) - Length of time (in minutes, between 5 and 15) a notification to be sent to the VM on the instance metadata server till the VM gets deleted. The time duration should be specified in ISO 8601 format. Defaults to PT5M.
  })

  Example Inputs:

  ```terraform
  termination_notification = {
    enabled = true
    timeout = "PT5M"

  }
  ```
  TERMINATION_NOTIFICATION
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
  description = <<VM_ADDITIONAL_CAPABILITIES
  object({
    ultra_ssd_enabled = "(Optional) Should the capacity to enable Data Disks of the `UltraSSD_LRS` storage account type be supported on this Virtual Machine? Defaults to `false`."
  })

  Example Inputs:

  ```terraform
  vm_additional_capabilities = {
    ultra_ssd_enabled = true
  }
  ```
  VM_ADDITIONAL_CAPABILITIES
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
  description = <<WINRM_LISTENERS
  set(object({
    protocol        = "(Required) Specifies Specifies the protocol of listener. Possible values are `Http` or `Https`"
    certificate_url = "(Optional) The Secret URL of a Key Vault Certificate, which must be specified when `protocol` is set to `Https`. Changing this forces a new resource to be created."
  }))

  Example Inputs: TODO: Validate this example

  ```terraform
  winrm_listeners = {
    protocol = "Https"
    certificate_url = data.azurerm_keyvault_secret.example.secret_id
  }
  ```
  WINRM_LISTENERS
  nullable    = false
}

variable "zone" {
  type        = string
  default     = null
  description = "(Optional) The Availability Zone which the Virtual Machine should be allocated in, only one zone would be accepted. If set then this module won't create `azurerm_availability_set` resource. Changing this forces a new resource to be created."
}

variable "gallery_applications" {
  type = list(object({
    version_id             = string
    configuration_blob_uri = optional(string)
    order                  = optional(number, 0)
    tag                    = optional(string)
  }))
  default     = []
  description = <<GALLERY_APPLICATIONS
  list(object({
    version_id             = "(Required) Specifies the Gallery Application Version resource ID."
    configuration_blob_uri = "(Optional) Specifies the URI to an Azure Blob that will replace the default configuration for the package if provided."
    order                  = "(Optional) Specifies the order in which the packages have to be installed. Possible values are between `0` and `2,147,483,647`."
    tag                    = "(Optional) Specifies a passthrough value for more generic context. This field can be any valid `string` value."
  }))

  Example Inputs:

  ```terraform
  gallery_applications = [
    {
      version_id = "/subscriptions/{subscriptionId}/resourceGroups/<resource group>/providers/Microsoft.Compute/galleries/{gallery name}/applications/{application name}/versions/{version}"
      order      = 1
  ]
  ```
  GALLERY_APPLICATIONS
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
  nullable    = false
  description = <<SECRETS
  list(object({
    key_vault_id = "(Required) The ID of the Key Vault from which all Secrets should be sourced."
    certificate  = set(object({
      url   = "(Required) The Secret URL of a Key Vault Certificate. This can be sourced from the `secret_id` field within the `azurerm_key_vault_certificate` Resource."
      store = "(Optional) The certificate store on the Virtual Machine where the certificate should be added. Required when use with Windows Virtual Machine."
    }))
  }))

  Example Inputs:

  ```terraform
  secrets = [
    {
      key_vault_id = azurerm_key_vault.example.id
      certificate = [
        {
          url = azurerm_key_vault_certificate.example.secret_id
          store = "My"
        }
      ]
    }
  ]
  ```
  SECRETS
}


#extension related settings
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
    provision_after_extensions  = optional(list(string), [])
    tags                        = optional(map(any))
    inherit_tags                = optional(bool, false)
    protected_settings_from_key_vault = optional(object({
      secret_url      = string
      source_vault_id = string
    }))
  }))
  # tflint-ignore: terraform_sensitive_variable_no_default
  default     = []
  description = <<EXTENSIONS
    Argument to create any additional `azurerm_virtual_machine_extension` resource, the argument descriptions could be found at [the document](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension).
    set(object({
      name                           = (Required) - Set a custom name on this value if you want the guest configuration extension to have a custom name
      publisher                      = (Required) - Configure the publisher for the extension to be deployed. The Publisher and Type of Virtual Machine Extensions can be found using the Azure CLI, via: az vm extension image list --location westus -o table
      type                           = (Required) - Configure the type value for the extension to be deployed. 
      type_handler_version           = (Required) - The type handler version for the extension. A common value is 1.0.
      auto_upgrade_minor_version     = (Optional) - Set this to false to avoid automatic upgrades for minor versions on the extension.  Defaults to true
      automatic_upgrade_enabled      = (Optional) - Set this to false to avoid automatic upgrades for major versions on the extension.  Defaults to true
      failure_suppression_enabled    = (Optional) - Should failures from the extension be suppressed? Possible values are true or false. Defaults to false. Operational failures such as not connecting to the VM will not be suppressed regardless of the failure_suppression_enabled value.
      settings                       = (Optional) - The settings passed to the extension, these are specified as a JSON object in a string. Certain VM Extensions require that the keys in the settings block are case sensitive. If you're seeing unhelpful errors, please ensure the keys are consistent with how Azure is expecting them (for instance, for the JsonADDomainExtension extension, the keys are expected to be in TitleCase.)
      protected_settings             = (Optional) - The protected_settings passed to the extension, like settings, these are specified as a JSON object in a string. Certain VM Extensions require that the keys in the protected_settings block are case sensitive. If you're seeing unhelpful errors, please ensure the keys are consistent with how Azure is expecting them (for instance, for the JsonADDomainExtension extension, the keys are expected to be in TitleCase.)
      provision_after_extensions     = optional(list(string)) [
        (Optional) - Specifies the collection of extension names after which this extension needs to be provisioned.
      ]      
      protected_settings_from_key_vault = optional(object({   #protected_settings_from_key_vault cannot be used with protected_settings
        secret_url      = (Required) - The Secret URL of a Key Vault Certificate. This can be sourced from the `secret_id` field within the `azurerm_key_vault_certificate` Resource.
        source_vault_id = (Required) - the Azure resource ID of the key vault holding the secret
      }))
      tags                           = (Optional) - A mapping of tags to assign to the resource.
      inherit_tags                   = (Optional) - Defaults to false.  Set this to false if only the tags defined on this resource should be applied. This is future functionality and is currently ignored.
    }))

    Example Inputs:

    ```terraform
    #custom script extension example - linux
    extensions = [
      {
        name = "CustomScriptExtension"
        publisher = "Microsoft.Azure.Extensions"
        type = "CustomScript"
        type_handler_version = "2.0"
        settings = <<SETTINGS
          {
            "script": "<base 64 encoded script file>"
          }
        SETTINGS
      }
    ]

    #custom script extension example - windows
    extensions = [
      {
        name = "CustomScriptExtension"
        publisher = "Microsoft.Compute"
        type = "CustomScriptExtension"
        type_handler_version = "1.10"
        settings = <<SETTINGS
          {
            "timestamp":123456789
          }
        SETTINGS
        protected_settings = <<PROTECTED_SETTINGS
          {
            "commandToExecute": "myExecutionCommand",
            "storageAccountName": "myStorageAccountName",
            "storageAccountKey": "myStorageAccountKey",
            "managedIdentity" : {},
            "fileUris": [
                "script location"
            ]
          }
        PROTECTED_SETTINGS        
      }
    ]
    ```
   EXTENSIONS
  nullable    = false
  sensitive   = true # Because `protected_settings` is sensitive

  validation {
    condition = length(var.extensions) == length(distinct([
      for e in var.extensions : e.type
    ]))
    error_message = "`type` in `vm_extensions` must be unique."
  }
}

variable "azure_monitor_agent_enabled" {
  type        = bool
  default     = true
  description = "When true this setting will enable the Azure Monitor Agent Extension on the VM. If set to false the Agent will not be installed"
}

variable "azure_monitor_agent_extension_settings" {
  type = object({
    name                                       = optional(string)
    type_handler_version                       = optional(string, "1.0")
    auto_upgrade_minor_version                 = optional(bool, true)
    automatic_upgrade_enabled                  = optional(bool, true)
    managed_identity_type                      = optional(string, "SystemAssigned")
    user_assigned_managed_identity_resource_id = optional(string)
    tags                                       = optional(map(any))
    inherit_tags                               = optional(bool, false)
  })
  default     = {}
  description = <<AZURE_MONITOR_AGENT_EXTENSION_SETTINGS
  This object defines the azure monitor agent configuration.   
  object({

    name                                       = (Optional) - The custom name to use for the Azure Monitor Agent extension installation
    type_handler_version                       = (Optional) - The type handler version for the extension. Default is 1.0.
    auto_upgrade_minor_version                 = (Optional) - Set this to false to avoid automatic upgrades for minor versions on the extension.  Defaults to true
    automatic_upgrade_enabled                  = (Optional) - Set this to false to avoid automatic upgrades for major versions on the extension.  Defaults to true
    managed_identity_type                      = (Optional) - Specifies the type of Managed Service Identity that should be used by the Azure Monitor Agent. Possible values are `SystemAssigned`, `UserAssigned`
    user_assigned_managed_identity_resource_id = (Optional) - The Azure Resource ID of the User Assigned Managed Identity to be used by the Azure Monitor Agent.
    tags                                       = (Optional) - A mapping of tags to assign to the resource.
    inherit_tags                               = (Optional) - Defaults to false.  Set this to false if only the tags defined on this resource should be applied. This is future functionality and is currently ignored.
  })

  Example Inputs:

  ```terraform
  #for the most common configuration no overriding of defaults is required
  #The following example shows a user assigned managed identity example.
  azure_monitor_agent_extension_settings = {
    name = "ExampleName"
    managed_identity_type = "UserAssigned"
    user_assigned_managed_identity_resource_id = azurerm_user_assigned_identity.example.id
  }
  ```
  AZURE_MONITOR_AGENT_EXTENSION_SETTINGS  
}

variable "azure_monitor_data_collection_rule_associations" {
  type = list(object({
    name                             = string
    data_collection_rule_resource_id = string
    description                      = optional(string)
  }))
  default     = []
  description = <<AZURE_MONITOR_DATA_COLLECTION_RULE_ASSOCIATIONS
  This list of objects defines one or more data collection endpoint associations to create. Requires that the azure_monitor_agent_enabled value be set to true.
  list(object({
    name                                 = (Required) - The name which should be used for this Data Collection Rule Association. Changing this forces a new Data Collection Rule Association to be created.
    data_collection_endpoint_resource_id = (Required) - The Azure Resource ID of the Data Collection Rule which will be associated to the target resource.
    description                          = (Optional) - The description of the Data Collection Rule Association.
  }))

  Example Inputs:

  ```terraform
    #Basic Input
    azure_monitor_data_collection_rule_associations = [
      {
      name                                 = "dcr_example"
      data_collection_endpoint_resource_id = azurerm_monitor_data_collection_rule.test.id
      description                          = "Association for test Data Collection Rule" 
      }
    ]
  ```
  AZURE_MONITOR_DATA_COLLECTION_RULE_ASSOCIATIONS
}

variable "azure_monitor_data_collection_endpoint_associations" {
  type = list(object({
    name                                 = string
    data_collection_endpoint_resource_id = string
    description                          = optional(string)
  }))
  default     = []
  description = <<AZURE_MONITOR_DATA_COLLECTION_ENDPOINT_ASSOCIATIONS
  "This list of objects defines one or more data collection endpoint associations to create. Requires that the azure_monitor_agent_enabled value be set to true."
  list(object({
    name                                 = (Required) - The name which should be used for this Data Collection Endpoint Association. Changing this forces a new Data Collection Endpoint Association to be created.
    data_collection_endpoint_resource_id = (Required) - The Azure Resource ID of the Data Collection Endpoint which will be associated to the target resource.
    description                          = (Optional) - The description of the Data Collection Endpoint Association.
  }))

  Example Inputs:

  ```terraform
    #Basic Input
    azure_monitor_data_collection_endpoint_associations = [
      {
      name                                 = "dce_example"
      data_collection_endpoint_resource_id = azurerm_monitor_data_collection_endpoint.test.id
      description                          = "Association for test Data Collection Endpoint" 
      }
    ]
  ```
  AZURE_MONITOR_DATA_COLLECTION_ENDPOINT_ASSOCIATIONS
}

variable "domain_join_the_windows_vm" {
  type        = bool
  default     = false
  description = "Set this value to true if a Windows VM is to be joined to an Active Directory Domain Services Domain."
}

variable "domain_join_extension_values" {
  type = object({
    domain_name                            = string
    domain_join_user_name                  = string
    domain_join_ou_path_for_vm             = optional(string, "Computers")
    domain_join_restart                    = optional(bool, true)
    domain_join_options                    = optional(number, 3)
    domain_join_user_key_vault_secret_name = optional(string)
    domain_join_user_key_vault_resource_id = optional(string)
    domain_join_user_password              = optional(string)
    tags                                   = optional(map(any))
    inherit_tags                           = optional(bool, false)
  })
  sensitive = true
  default = {
    domain_name           = ""
    domain_join_user_name = ""
  }

  description = <<DOMAIN_JOIN_EXTENSION_VALUES
  object({  
    domain_name                            = (Required) - The domain name of the target domain if a Windows VM is to be joined to an Active Directory Domain Services Domain.
    domain_join_user_name                  = (Required) - A user in the target domain with permissions to join Windows virtual machines. It is recommended that this is NOT a domain admin.
    domain_join_ou_path_for_vm             = (Optional) - The optional OU path to use for placing the virtual machine computer object in the domain.
    domain_join_restart                    = (Optional) - Allow the domain join extension to restart the VM when domain joining. Defaults to true.
    domain_join_options                    = (Optional) - Domain join options for the domain join extension. Details can be found here https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/joindomainorworkgroup-method-in-class-win32-computersystem
    domain_join_user_key_vault_secret_name = (Optional) - The name of the key vault secret value that holds the domain join users password
    domain_join_user_key_vault_resource_id = (Optional) - the Azure resource ID of the key vault holding the domain join user's password secret
    domain_join_user_password              = (Optional) - Password value for the domain join user. The default is that this will pull from a key vault and this can remain null. Setting both this value and a password key vault value will result in this value being set
    tags                                   = (Optional) - A mapping of tags to assign to the resource.
    inherit_tags                           = (Optional) - Defaults to false.  Set this to false if only the tags defined on this resource should be applied. This is future functionality and can be ignored.
  }
  
  Example Inputs:

  ```terraform
    #Basic password based input
    domain_join_extension_values = {
      domain_name               = "testdomain.com"
      domain_join_user_name     = "domainjoinuser"
      domain_join_user_password = "1SuperSecretPassword!" 
    }

    #Basic Key Vault Based Input. It is also common for the key vault resource ID to be a terraform resource reference like azurerm_key_vault.example.id
    domain_join_extension_values = {
      domain_name           = "testdomain.com"
      domain_join_user_name = "domainjoinuser"
      domain_join_user_key_vault_secret_name = "domain_join_password_secret" 
      domain_join_user_key_vault_resource_id = "/subscriptions/0000000-0000-0000-0000-000000000000/resourceGroups/test-resource-group/providers/Microsoft.KeyVault/vaults/example-key-vault"
    } 
  ```
  DOMAIN_JOIN_EXTENSION_VALUES
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    scope_resource_id                      = string
    role_definition_name                   = optional(string)
    condition                              = optional(string)
    condition_version                      = optional(string)
    description                            = optional(string)
    skip_service_principal_aad_check       = optional(bool, true)
    delegated_managed_identity_resource_id = optional(string)
    }
  ))
  default = {}

  description = <<SYSTEM_MANAGED_IDENTITY_ROLE_ASSIGNMENTS
  A list of role definitions and scopes to be assigned to the system managed identity
  list(object({
    scope_resource_id                = (Required) - The scope at which the Role Assignment applies to, such as /subscriptions/0b1f6471-1bf0-4dda-aec3-111122223333, /subscriptions/0b1f6471-1bf0-4dda-aec3-111122223333/resourceGroups/myGroup, or /subscriptions/0b1f6471-1bf0-4dda-aec3-111122223333/resourceGroups/myGroup/providers/Microsoft.Compute/virtualMachines/myVM, or /providers/Microsoft.Management/managementGroups/myMG. Changing this forces a new resource to be created.
    role_definition_resource_id      = (Optional) - The Scoped-ID of the Role Definition. Changing this forces a new resource to be created. Conflicts with role_definition_name
    role_definition_name             = (Optional) - The name of a built-in Role. Changing this forces a new resource to be created. Conflicts with role_definition_id
    condition                        = (Optional) - The condition that limits the resources that the role can be assigned to. Changing this forces a new resource to be created.
    condition_version                = (Optional) - The version of the condition. Possible values are 1.0 or 2.0. Changing this forces a new resource to be created.
    description                      = (Optional) - The description for this Role Assignment. Changing this forces a new resource to be created.
    skip_service_principal_aad_check = (Optional) - If the principal_id is a newly provisioned Service Principal set this value to true to skip the Azure Active Directory check which may fail due to replication lag. This argument is only valid if the principal_id is a Service Principal identity. Defaults to true.
    delegated_managed_identity_resource_id = ""
  }))

  Example Inputs:

  ```terraform
    #typical assignment example. It is also common for the scope resource ID to be a terraform resource reference like azurerm_resource_group.example.id
    role_assignments = {
      role_assignment_1 = {
        scope_resource_id    = "/subscriptions/0000000-0000-0000-0000-000000000000/resourceGroups/test_resource_group/providers/Microsoft.Storage/storageAccounts/examplestorageacct"
        role_definition_id_or_name = "Storage Blob Data Contributor"
        description          = "Example for assigning a role to a resource"
      }
    }
  ```
  SYSTEM_MANAGED_IDENTITY_ROLE_ASSIGNMENTS 
}

variable "azure_guest_configuration_extension" {
  type = object({
    guest_config_extension_enabled = optional(bool, true)
    name                           = optional(string)
    type_handler_version           = optional(string, "1.0")
    auto_upgrade_minor_version     = optional(bool, true)
    automatic_upgrade_enabled      = optional(bool, true)
    settings                       = optional(string)
    protected_settings             = optional(string)
    tags                           = optional(map(any))
    inherit_tags                   = optional(bool, false)
  })
  default = {
    guest_config_extension_enabled = true
  }
  description = <<AZURE_GUEST_CONFIGURATION_EXTENSION
  "Values for the guest configuration extension"
  object({
    guest_config_extension_enabled = (Optional) - Set this to false if you want to disable the guest configuration extension
    name                           = (Optional) - Set a custom name on this value if you want the guest configuration extension to have a custom name
    type_handler_version           = (Optional) - The type handler version for the extension. Default is 1.0.
    auto_upgrade_minor_version     = (Optional) - Set this to false to avoid automatic upgrades for minor versions on the extension.  Defaults to true
    automatic_upgrade_enabled      = (Optional) - Set this to false to avoid automatic upgrades for major versions on the extension.  Defaults to true
    settings                       = (Optional) - Passing through this value in case we need to allow custom settings on the extension in the future.  Unused in the default case.
    protected_settings             = (Optional) - Passing through this value in case we need to allow custom protected_settings on the extension in the future.  Unused in the default case.
    tags                           = (Optional) - A mapping of tags to assign to the resource.
    inherit_tags                   = (Optional) - Defaults to false.  Set this to false if only the tags defined on this resource should be applied. This is future functionality and can be ignored.
  }

  Example Inputs:

  ```terraform
    azure_guest_configuration_extensions = {
      guest_config_extension_enabled = false
    }

  ```
  AZURE_GUEST_CONFIGURATION_EXTENSION
}

variable "enable_azure_backup" {
  type        = bool
  default     = false
  description = "Flag to determine whether to enable azure backup on this VM. Requires the backup configuration variable to be populated."
}

variable "azure_backup_configuration" {
  type = object({
    recovery_vault_resource_group_name = string
    recovery_vault_name                = string
    backup_policy_resource_id          = optional(string)
    exclude_disk_luns                  = optional(list(number))
    include_disk_luns                  = optional(list(number))
    protection_state                   = optional(string)
  })
  default     = null
  description = <<AZURE_BACKUP_CONFIGURATION
  Configuration details for the Azure backup policy that this VM will use.
  object({
    recovery_vault_resource_group_name = (Required) - The resource group name of the recovery services vault.  Allows the vault to existing in a different resource group. 
    recovery_vault_name                = (Required) - The name of the recovery services vault to use for the backup.  
    backup_policy_resource_id          = (Optional/Required) - The Azure Resource ID of the backup policy to use for the backup of this VM. Required in creation or when `protection_stopped` is not specified.
    exclude_disk_luns                  = (Optional) - A list of Disks' Logical Unit Numbers(LUN) to be excluded for VM Protection.
    include_disk_luns                  = (Optional) - A list of Disks' Logical Unit Numbers(LUN) to be included for VM Protection.
    protection_state                   = (Optional) Specifies Protection state of the backup. Possible values are Invalid, IRPending, Protected, ProtectionStopped, ProtectionError and ProtectionPaused.
  }

  Example Inputs:

  ```terraform
    #Simple Standard Configuration
    azure_backup_configuration = {
      recovery_vault_resource_group_name = "test_resource_group_name"
      recovery_vault_name                = "test_recovery_services_vault"
      backup_policy_resource_id          = "/subscriptions/0000000-0000-0000-0000-000000000000/resourceGroups/test_resource_group_name/providers/Microsoft.RecoveryServices/vaults/test_recovery_services_vault/backupPolicies/DefaultPolicy"
    }

    #full sample
    azure_backup_configuration = {
      recovery_vault_resource_group_name = "test_resource_group_name"
      recovery_vault_name                = "test_recovery_services_vault"
      backup_policy_resource_id          = "/subscriptions/0000000-0000-0000-0000-000000000000/resourceGroups/test_resource_group_name/providers/Microsoft.RecoveryServices/vaults/test_recovery_services_vault/backupPolicies/DefaultPolicy"
      exclude_disk_luns                  = [2,3]
      include_disk_luns                  = [0,1]
      protection_state                   = "Protected"
    }
  ```
  AZURE_BACKUP_CONFIGURATION

}

#Future work to complete
variable "append_name_string_suffix" {
  type        = bool
  description = "Disable this to remove the partial hash value used to ensure sub-resource naming uniqueness"
  default     = false
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

