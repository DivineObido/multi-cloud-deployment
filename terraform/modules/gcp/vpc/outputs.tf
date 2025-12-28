# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "vpc_self_link" {
  description = "Self-link of the VPC network"
  value       = google_compute_network.main.self_link
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = google_compute_subnetwork.public[*].id
}

output "public_subnet_names" {
  description = "Names of the public subnets"
  value       = google_compute_subnetwork.public[*].name
}

output "public_subnet_self_links" {
  description = "Self-links of the public subnets"
  value       = google_compute_subnetwork.public[*].self_link
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = google_compute_subnetwork.private[*].id
}

output "private_subnet_names" {
  description = "Names of the private subnets"
  value       = google_compute_subnetwork.private[*].name
}

output "private_subnet_self_links" {
  description = "Self-links of the private subnets"
  value       = google_compute_subnetwork.private[*].self_link
}

# NAT and Router Outputs
output "cloud_router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.main.name
}

output "nat_gateway_name" {
  description = "Name of the Cloud NAT gateway"
  value       = google_compute_router_nat.main.name
}

output "nat_ip_addresses" {
  description = "External IP addresses used by NAT gateway"
  value       = google_compute_address.nat[*].address
}

# Network CIDR Outputs
output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = var.vpc_cidr
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = var.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = var.private_subnet_cidrs
}