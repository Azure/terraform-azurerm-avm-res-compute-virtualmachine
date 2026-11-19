terraform {
  required_version = ">= 1.16, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    # v0.21.0 builds the machines with the azurerm provider. Declaring it here is what passes the
    # test file's provider configuration down to the module.
    # tflint-ignore: terraform_unused_required_providers
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.42, < 5.0"
    }
  }
}
