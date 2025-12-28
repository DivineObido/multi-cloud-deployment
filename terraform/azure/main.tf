terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Virtual Network Module
module "vnet" {
  source = "../modules/azure/vnet"

  environment          = var.environment
  project_name         = var.project_name
  azure_region         = var.azure_region
  vnet_cidr           = var.vnet_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr
}

# Container Instance Module
module "aci" {
  source = "../modules/azure/aci"

  environment             = var.environment
  project_name            = var.project_name
  app_name               = var.app_name
  resource_group_name     = module.vnet.resource_group_name
  resource_group_location = module.vnet.resource_group_location
  vnet_name              = module.vnet.vnet_name
  public_subnet_id        = module.vnet.public_subnet_id
  private_subnet_id       = module.vnet.private_subnet_id
  container_image         = var.container_image
  container_port          = var.container_port
  container_cpu           = var.container_cpu
  container_memory        = var.container_memory
  instance_count          = var.instance_count
  environment_variables   = var.environment_variables
}

# Traffic Manager Profile for health monitoring
resource "azurerm_traffic_manager_profile" "main" {
  name                   = "${var.environment}-${var.app_name}-tm"
  resource_group_name    = module.vnet.resource_group_name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "${var.environment}-${var.app_name}"
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                        = 80
    path                        = "/health"
    interval_in_seconds         = 30
    timeout_in_seconds          = 10
    tolerated_number_of_failures = 3
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}