terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
}