variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "app"
}

variable "aws_endpoint" {
  description = "AWS application endpoint (ALB DNS name)"
  type        = string
}

variable "azure_endpoint" {
  description = "Azure application endpoint (Application Gateway IP)"
  type        = string
}

variable "gcp_endpoint" {
  description = "GCP application endpoint (Load Balancer IP)"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 60
}

variable "failover_threshold" {
  description = "Number of failed health checks before failover"
  type        = number
  default     = 3
}

variable "session_affinity_ttl" {
  description = "Session affinity TTL in seconds"
  type        = number
  default     = 3600
}