# Project Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
  validation {
    condition     = length(var.project_id) > 0
    error_message = "The project_id cannot be empty."
  }
}

variable "gcp_region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
      "europe-west1", "europe-west2", "europe-west3", "europe-west4", "europe-west6",
      "asia-east1", "asia-northeast1", "asia-south1", "asia-southeast1"
    ], var.gcp_region)
    error_message = "The gcp_region must be a valid GCP region."
  }
}

variable "zones" {
  description = "The GCP zones for resources"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b"]
  validation {
    condition     = length(var.zones) >= 2
    error_message = "At least two zones must be specified for high availability."
  }
}

# Environment Configuration
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multi-cloud-app"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "web-app"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "App name must contain only lowercase letters, numbers, and hyphens."
  }
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.2.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs must be provided."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.2.10.0/24", "10.2.20.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs must be provided."
  }
}

# Application Configuration
variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "gcr.io/cloudrun/hello"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._/-]*[a-zA-Z0-9]$", var.container_image))
    error_message = "Container image must be a valid image reference."
  }
}

variable "container_port" {
  description = "Port that the container listens on"
  type        = number
  default     = 8080
  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "service_cpu" {
  description = "CPU allocation for Cloud Run service"
  type        = string
  default     = "1000m"
  validation {
    condition     = can(regex("^[0-9]+m$", var.service_cpu))
    error_message = "Service CPU must be specified in millicores (e.g., 1000m)."
  }
}

variable "service_memory" {
  description = "Memory allocation for Cloud Run service"
  type        = string
  default     = "512Mi"
  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi)$", var.service_memory))
    error_message = "Service memory must be specified with Mi or Gi suffix (e.g., 512Mi, 2Gi)."
  }
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
  validation {
    condition     = var.min_instances >= 0
    error_message = "Minimum instances must be a non-negative number."
  }
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
  validation {
    condition     = var.max_instances > 0 && var.max_instances >= var.min_instances
    error_message = "Maximum instances must be positive and >= minimum instances."
  }
}

variable "environment_variables" {
  description = "Environment variables for the application"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "CLOUD_PROVIDER"
      value = "GCP"
    }
  ]
}