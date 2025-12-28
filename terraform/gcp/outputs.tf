# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = module.vpc.vpc_name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# Cloud Run Outputs
output "service_url" {
  description = "URL of the Cloud Run service"
  value       = module.cloud_run.service_url
  sensitive   = false
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = module.cloud_run.service_name
}

output "service_location" {
  description = "Location of the Cloud Run service"
  value       = module.cloud_run.service_location
}

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = module.cloud_run.load_balancer_ip
}

output "health_check_path" {
  description = "Health check path"
  value       = "/health"
}

# Project Information
output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.gcp_region
}