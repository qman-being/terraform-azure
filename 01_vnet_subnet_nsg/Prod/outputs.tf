output "vnet_id" {
  value       = azurerm_virtual_network.vnet.id
  description = "Outputs the vNet ID"
}

output "vm_snet_id" {
  value       = azurerm_subnet.vm_subnet.id
  description = "Outputs the subnet ID"
}