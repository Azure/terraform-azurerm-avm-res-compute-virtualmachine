terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">=1.9.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}