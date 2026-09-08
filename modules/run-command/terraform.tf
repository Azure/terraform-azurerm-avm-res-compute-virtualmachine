terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    # The AVM toolchain declares azapi in every terraform.tf it manages, and regenerates it on each
    # pre-commit run, so the declaration cannot simply be removed. This submodule still holds its
    # azurerm resource until the run command migration step lands, so azapi is declared here but not
    # yet used. Drop this ignore once the submodule is on azapi.
    # tflint-ignore: terraform_unused_required_providers
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116, < 5.0"
    }
  }
}
