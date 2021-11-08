variable "tenant_id" {}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.79.1"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  tenant_id = var.tenant_id
  #subscription_id = "c5fc7c8f-2c02-43e6-a7ad-549a7f1a0ec5"
  features {}
}
