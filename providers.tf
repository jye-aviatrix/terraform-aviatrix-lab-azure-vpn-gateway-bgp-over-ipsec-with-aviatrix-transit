terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
  }
}

provider "azurerm" {
  features {}
}