variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multi-cloud-app"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "web-app"
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.1.10.0/24"
}

variable "container_image" {
  description = "Docker image for the container"
  type        = string
  default     = "nginx:latest"
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
  description = "Memory allocation for container in GB"
  type        = number
  default     = 1
}

variable "instance_count" {
  description = "Number of container instances"
  type        = number
  default     = 2
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default = {
    NODE_ENV       = "production"
    CLOUD_PROVIDER = "Azure"
  }
}