# Service Outputs
output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.name
}

output "service_id" {
  description = "ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.id
}

output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.uri
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.location
}

# Load Balancer Outputs
output "load_balancer_ip" {
  description = "External IP address of the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "load_balancer_hostname" {
  description = "Hostname for the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

# Service Account Outputs
output "service_account_email" {
  description = "Email of the service account used by Cloud Run"
  value       = google_service_account.cloud_run.email
}

output "service_account_id" {
  description = "ID of the service account used by Cloud Run"
  value       = google_service_account.cloud_run.id
}

# Health Check Outputs
output "health_check_name" {
  description = "Name of the health check"
  value       = google_compute_health_check.cloud_run.name
}

output "health_check_path" {
  description = "Path used for health checks"
  value       = "/health"
}

# SSL Certificate Outputs
output "ssl_certificate_id" {
  description = "ID of the managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.lb_cert.id
}

output "ssl_certificate_status" {
  description = "Status of the managed SSL certificate"
  value       = "ACTIVE"
}

# Backend Service Outputs
output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.cloud_run.name
}

# Monitoring Outputs
output "uptime_check_name" {
  description = "Name of the uptime check"
  value       = google_monitoring_uptime_check_config.cloud_run.display_name
}

# Security Outputs
output "ssl_policy_name" {
  description = "Name of the SSL policy"
  value       = google_compute_ssl_policy.modern.name
}

# URL Map Outputs
output "url_map_name" {
  description = "Name of the URL map"
  value       = google_compute_url_map.cloud_run.name
}