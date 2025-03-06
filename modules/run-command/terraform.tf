terraform {
  required_version = "~> 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116, < 5.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}
