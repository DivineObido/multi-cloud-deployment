output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.vnet.resource_group_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.vnet.vnet_id
}

output "application_gateway_public_ip" {
  description = "Public IP address of the application gateway"
  value       = module.aci.application_gateway_public_ip
}

output "container_registry_login_server" {
  description = "Login server of the container registry"
  value       = module.aci.container_registry_login_server
}

output "container_registry_admin_username" {
  description = "Admin username of the container registry"
  value       = module.aci.container_registry_admin_username
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "Admin password of the container registry"
  value       = module.aci.container_registry_admin_password
  sensitive   = true
}

output "traffic_manager_fqdn" {
  description = "FQDN of the traffic manager profile"
  value       = azurerm_traffic_manager_profile.main.fqdn
}

output "azure_endpoint" {
  description = "Azure application endpoint"
  value       = module.aci.azure_endpoint
}