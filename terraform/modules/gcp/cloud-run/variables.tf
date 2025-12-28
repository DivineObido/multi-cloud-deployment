# Project Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region for resources"
  type        = string
}

# Network Configuration
variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "private_subnet_names" {
  description = "Names of the private subnets"
  type        = list(string)
}

# Application Configuration
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "container_port" {
  description = "Port that the container listens on"
  type        = number
}

variable "service_cpu" {
  description = "CPU allocation for Cloud Run service"
  type        = string
}

variable "service_memory" {
  description = "Memory allocation for Cloud Run service"
  type        = string
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
}

variable "environment_variables" {
  description = "Environment variables for the application"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Cost Monitoring Configuration
variable "billing_account_id" {
  description = "GCP billing account ID for budget alerts"
  type        = string
}

variable "budget_alert_channels" {
  description = "List of notification channels for budget alerts"
  type        = list(string)
  default     = []
}