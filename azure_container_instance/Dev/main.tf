terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.34.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    key                  = "dev.networking.terraform.tfstate"
    container_name       = "dev-tfstate"
    resource_group_name  = "rg-storage-prod-san-01"
    storage_account_name = "stprodtfsan01"
  }
}

locals {
  common_tags = {
    environment = var.tag_environment
    createdby   = "Terraform"
    createdon   = formatdate("DD-MM-YYYY hh:mm ZZZ", timestamp())
  }
}

resource "azurerm_resource_group" "aci_rg" {
  name     = var.rg_name
  location = var.rg_location
  tags     = merge(local.common_tags)
}

resource "azurerm_network_profile" "aci_np" {
  name                = "${var.aci_name}-profile"
  location            = azurerm_resource_group.aci_rg.location
  resource_group_name = azurerm_resource_group.aci_rg.name

  container_network_interface {
    name = "${var.aci_name}-nic"

    ip_configuration {
      name      = "containeripconfig"
      subnet_id = data.terraform_remote_state.networking.outputs.aci_snet_id
    }
  }
}

resource "azurerm_container_group" "aci" {
  name                = var.aci_name
  location            = azurerm_resource_group.aci_rg.location
  resource_group_name = azurerm_resource_group.aci_rg.name
  ip_address_type     = "Private"
  network_profile_id  = azurerm_network_profile.aci_np.id
  os_type             = "Linux"

  container {
    name         = var.container_name
    image        = var.container_image
    cpu          = "1.0"
    memory       = "1.0"
    cpu_limit    = "1.0"
    memory_limit = "1.0"
    environment_variables = {
      "AZP_URL"        = var.azp_url
      "AZP_TOKEN"      = var.azp_token
      "AZP_AGENT_NAME" = var.container_name
    }
  }
}