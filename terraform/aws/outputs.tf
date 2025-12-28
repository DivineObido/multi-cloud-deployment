output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.ecs.load_balancer_dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = module.ecs.load_balancer_zone_id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "health_check_id" {
  description = "ID of the Route53 health check"
  value       = aws_route53_health_check.app.id
}

output "aws_endpoint" {
  description = "AWS application endpoint"
  value       = "http://${module.ecs.load_balancer_dns_name}"
}