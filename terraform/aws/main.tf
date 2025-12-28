terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Cloud       = "AWS"
    }
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "../modules/aws/vpc"

  vpc_cidr               = var.vpc_cidr
  availability_zones     = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  environment           = var.environment
  project_name          = var.project_name
}

# ECS Module
module "ecs" {
  source = "../modules/aws/ecs"

  environment         = var.environment
  project_name        = var.project_name
  app_name           = var.app_name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  container_image    = var.container_image
  container_port     = var.container_port
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  desired_count     = var.desired_count
  aws_region        = var.aws_region
  environment_variables = var.environment_variables
}

# Route53 Health Check
resource "aws_route53_health_check" "app" {
  fqdn                            = module.ecs.load_balancer_dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = 3
  request_interval                = 30

  tags = {
    Name        = "${var.environment}-${var.app_name}-health-check"
    Environment = var.environment
    Project     = var.project_name
    Cloud       = "AWS"
  }
}