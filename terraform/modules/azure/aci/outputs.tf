output "container_registry_name" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Login server of the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "container_registry_admin_username" {
  description = "Admin username of the container registry"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "Admin password of the container registry"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

output "application_gateway_public_ip" {
  description = "Public IP address of the application gateway"
  value       = azurerm_public_ip.app_gateway.ip_address
}

output "application_gateway_fqdn" {
  description = "FQDN of the application gateway"
  value       = azurerm_public_ip.app_gateway.fqdn
}

output "container_group_ips" {
  description = "Private IP addresses of container groups"
  value       = azurerm_container_group.main[*].ip_address
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "azure_endpoint" {
  description = "Azure application endpoint"
  value       = "http://${azurerm_public_ip.app_gateway.ip_address}"
}