variable "location" {
  type        = string
  default     = "eastus2"
  description = "The Azure region for the test resources."
}

variable "sku_size" {
  type        = string
  default     = "Standard_D2s_v5"
  description = "The size of the test virtual machines."
}
