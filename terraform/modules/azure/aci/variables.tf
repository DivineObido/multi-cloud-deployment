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

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "Location of the resource group"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet"
  type        = string
}

variable "private_subnet_id" {
  description = "ID of the private subnet"
  type        = string
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "CPU allocation for container"
  type        = number
  default     = 1
}

variable "container_memory" {
  description = "Memory allocation for container"
  type        = number
  default     = 1
}

variable "instance_count" {
  description = "Number of container instances (deprecated - use min_instance_count)"
  type        = number
  default     = 2
}

variable "min_instance_count" {
  description = "Minimum number of container instances for cost optimization"
  type        = number
  default     = 1
}

variable "max_instance_count" {
  description = "Maximum number of container instances for scaling"
  type        = number
  default     = 5
}

variable "budget_alert_email" {
  description = "Email address for budget alerts"
  type        = string
  default     = "admin@example.com"
}

variable "resource_group_id" {
  description = "ID of the resource group"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}