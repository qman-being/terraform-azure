terraform {
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

terraform {
  required_version = ">= 1.0"
}

data "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmpassword"
  key_vault_id = var.kv_uri
}

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    key                  = "dev.networking.terraform.tfstate"
    container_name       = "dev-tfstate"
    resource_group_name  = "stprodtfsan01"
    storage_account_name = "MyStorageAccount"
  }
}

locals {
  common_tags = {
    environment = var.tag_environment
    createdby   = "Terraform"
    createdon   = formatdate("DD-MM-YYYY hh:mm ZZZ", timestamp())
  }
}

resource "azurerm_resource_group" "windows_vm_rg" {
  name     = var.rg_name
  location = var.rg_location
  tags     = merge(local.common_tags)
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.windows_vm_rg.location
  resource_group_name = azurerm_resource_group.windows_vm_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.networking.outputs.vm_snet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.windows_vm_rg.name
  location            = azurerm_resource_group.windows_vm_rg.location
  size                = var.vm_size
  admin_username      = var.vm_user
  admin_password      = data.azurerm_key_vault_secret.vmpassword.value
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.image_version
  }
}