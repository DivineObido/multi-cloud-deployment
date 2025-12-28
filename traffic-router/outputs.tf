output "load_balancer_hostname" {
  description = "Hostname of the load balancer"
  value       = cloudflare_load_balancer.main.name
}

output "aws_health_check_id" {
  description = "AWS health check ID"
  value       = aws_route53_health_check.aws_health.id
}

output "azure_health_check_id" {
  description = "Azure health check ID"
  value       = aws_route53_health_check.azure_health.id
}

output "gcp_health_check_id" {
  description = "GCP health check ID"
  value       = aws_route53_health_check.gcp_health.id
}

output "cloudflare_load_balancer_id" {
  description = "Cloudflare load balancer ID"
  value       = cloudflare_load_balancer.main.id
}

output "aws_pool_id" {
  description = "AWS pool ID"
  value       = cloudflare_load_balancer_pool.aws_pool.id
}

output "azure_pool_id" {
  description = "Azure pool ID"
  value       = cloudflare_load_balancer_pool.azure_pool.id
}

output "gcp_pool_id" {
  description = "GCP pool ID"
  value       = cloudflare_load_balancer_pool.gcp_pool.id
}

output "application_url" {
  description = "Public URL for the application"
  value       = "https://${cloudflare_load_balancer.main.name}"
}