# DNS-based traffic routing with health checks and failover
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Cloudflare provider configuration
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Data source for Cloudflare zone
data "cloudflare_zones" "domain" {
  filter {
    name = var.domain_name
  }
}

# AWS Route53 Health Checks
resource "aws_route53_health_check" "aws_health" {
  fqdn                            = replace(var.aws_endpoint, "http://", "")
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = 3
  request_interval                = 30
  measure_latency                 = true

  tags = {
    Name        = "${var.environment}-aws-health-check"
    Environment = var.environment
    Cloud       = "AWS"
  }
}

resource "aws_route53_health_check" "azure_health" {
  fqdn                            = replace(var.azure_endpoint, "http://", "")
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/health"
  failure_threshold               = 3
  request_interval                = 30
  measure_latency                 = true

  tags = {
    Name        = "${var.environment}-azure-health-check"
    Environment = var.environment
    Cloud       = "Azure"
  }
}

resource "aws_route53_health_check" "gcp_health" {
  fqdn                            = replace(var.gcp_endpoint, "http://", "")
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/health"
  failure_threshold               = 3
  request_interval                = 30
  measure_latency                 = true

  tags = {
    Name        = "${var.environment}-gcp-health-check"
    Environment = var.environment
    Cloud       = "GCP"
  }
}

# Cloudflare Load Balancer Pool for AWS
resource "cloudflare_load_balancer_pool" "aws_pool" {
  name = "${var.environment}-aws-pool"

  origins {
    name    = "aws-origin"
    address = replace(var.aws_endpoint, "http://", "")
    enabled = true
    weight  = 1
  }

  description = "AWS application pool"
  enabled     = true

  monitor = cloudflare_load_balancer_monitor.health_monitor.id
}

# Cloudflare Load Balancer Pool for Azure
resource "cloudflare_load_balancer_pool" "azure_pool" {
  name = "${var.environment}-azure-pool"

  origins {
    name    = "azure-origin"
    address = replace(var.azure_endpoint, "http://", "")
    enabled = true
    weight  = 1
  }

  description = "Azure application pool"
  enabled     = true

  monitor = cloudflare_load_balancer_monitor.health_monitor.id
}

# Cloudflare Load Balancer Pool for GCP
resource "cloudflare_load_balancer_pool" "gcp_pool" {
  name = "${var.environment}-gcp-pool"

  origins {
    name    = "gcp-origin"
    address = replace(var.gcp_endpoint, "http://", "")
    enabled = true
    weight  = 1
  }

  description = "GCP application pool"
  enabled     = true

  monitor = cloudflare_load_balancer_monitor.health_monitor.id
}

# Cloudflare Health Monitor
resource "cloudflare_load_balancer_monitor" "health_monitor" {
  expected_body   = "healthy"
  expected_codes  = "200"
  method          = "GET"
  timeout         = 10
  path            = "/health"
  interval        = 60
  retries         = 3
  description     = "Health monitor for multi-cloud application"
  type            = "http"
  port            = 80
  follow_redirects = true

  header {
    header = "Host"
    values = ["${var.subdomain}.${var.domain_name}"]
  }
}

# Cloudflare Load Balancer with intelligent routing
resource "cloudflare_load_balancer" "main" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = "${var.subdomain}.${var.domain_name}"
  fallback_pool_id = cloudflare_load_balancer_pool.aws_pool.id

  default_pool_ids = [
    cloudflare_load_balancer_pool.aws_pool.id,
    cloudflare_load_balancer_pool.azure_pool.id,
    cloudflare_load_balancer_pool.gcp_pool.id
  ]

  description = "Multi-cloud load balancer with intelligent routing"
  ttl         = 30
  proxied     = true
  enabled     = true

  # Geographic steering based on user location
  region_pools {
    region = "WNAM"  # Western North America - prefer AWS
    pool_ids = [
      cloudflare_load_balancer_pool.aws_pool.id,
      cloudflare_load_balancer_pool.gcp_pool.id,
      cloudflare_load_balancer_pool.azure_pool.id
    ]
  }

  region_pools {
    region = "ENAM"  # Eastern North America - prefer GCP
    pool_ids = [
      cloudflare_load_balancer_pool.gcp_pool.id,
      cloudflare_load_balancer_pool.aws_pool.id,
      cloudflare_load_balancer_pool.azure_pool.id
    ]
  }

  region_pools {
    region = "WEU"   # Western Europe - prefer Azure
    pool_ids = [
      cloudflare_load_balancer_pool.azure_pool.id,
      cloudflare_load_balancer_pool.gcp_pool.id,
      cloudflare_load_balancer_pool.aws_pool.id
    ]
  }

  region_pools {
    region = "APAC"  # Asia Pacific - prefer GCP
    pool_ids = [
      cloudflare_load_balancer_pool.gcp_pool.id,
      cloudflare_load_balancer_pool.aws_pool.id,
      cloudflare_load_balancer_pool.azure_pool.id
    ]
  }

  # Adaptive routing rules
  adaptive_routing {
    failover_across_pools = true
  }

  # Location-based steering
  location_strategy {
    prefer_ecs = "always"
    mode       = "resolver_ip"
  }

  # Session affinity for consistent user experience
  session_affinity = "cookie"
  session_affinity_ttl = 3600

  # Random steering when pools have equal priority
  random_steering {
    default_weight = 0.33
    pool_weights = {
      (cloudflare_load_balancer_pool.aws_pool.id)   = 0.33
      (cloudflare_load_balancer_pool.azure_pool.id) = 0.33
      (cloudflare_load_balancer_pool.gcp_pool.id)   = 0.34
    }
  }
}

# Cloudflare Page Rules for optimization
resource "cloudflare_page_rule" "api_cache" {
  zone_id  = data.cloudflare_zones.domain.zones[0].id
  target   = "${var.subdomain}.${var.domain_name}/api/*"
  priority = 1

  actions {
    cache_level         = "standard"
    edge_cache_ttl      = 300
    browser_cache_ttl   = 300
    always_online       = "on"
    automatic_https_rewrites = "on"
  }
}

resource "cloudflare_page_rule" "health_no_cache" {
  zone_id  = data.cloudflare_zones.domain.zones[0].id
  target   = "${var.subdomain}.${var.domain_name}/health"
  priority = 2

  actions {
    cache_level = "bypass"
  }
}