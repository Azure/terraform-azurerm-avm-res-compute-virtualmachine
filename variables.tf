# This is required for most resource modules
variable "resource_group" {
  type        = string
  description = "The resource group name of the resource group where the vm resources will be deployed."
  nullable    = false
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
  type = string
  description = "Name to use for the default admin account created for the virtual machine"
  default = "azureuser"
  nullable = false
}

variable "virtualmachine_sku_size" {
  type = string
  description = "The sku value to use for this virtual machine"
  default = "Standard_D2as_v4"
  nullable = false
}

variable "admin_credential_key_vault_resource_id" {
  type = string
  description = "The Azure resource ID for the key vault that stores admin credential information"
  nullable = false
}

variable "admin_ssh_key" {
  type = list(object({
    public_key = string
    username = string
  }))
  description = "A list of key objects including the public key 2048 bit RSA string, and the associated username to put the key in the user's home directory."
  default = []
}

variable "disable_password_authentication" {
  type = bool
  description = "If true this value will disallow password authentication on linux vm's. This will require at least one public key to be configured."
  default = false  
}

variable "generate_admin_password" {
  type = bool
  description = "Set this value to true if the deployment should create a strong password for the admin user."
  default = true
}

variable "admin_password_key_vault_secret_name" {
  type = string
  description = "The name of the key vault secret which should be used for the admin password"
  default = ""
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


variable "virtualmachine_network_interfaces" {
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


##Variables describing the disk configuration
variable "virtualmachine_data_disk_managed_disks" {
  type = list(object({
    name                                      = string
    storage_account_type                      = string
    lun                                       = number
    caching                                   = string
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
    })),[])
    #disk_encryption_set_resource_id = optional(string) #this is currently a preview feature in the provider 
  }))

  default = []
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

