# Local values for consistent naming and tagging
locals {
  common_labels = {
    environment   = var.environment
    project       = var.project_name
    application   = var.app_name
    managed_by    = "terraform"
    cloud         = "gcp"
    created_date  = formatdate("YYYY-MM-DD", timestamp())
  }

  service_name = "${var.environment}-${var.app_name}-service"
}

# Service Account for Cloud Run with minimal permissions
resource "google_service_account" "cloud_run" {
  account_id   = "${var.environment}-${var.app_name}-sa"
  display_name = "Cloud Run Service Account for ${var.environment} ${var.app_name}"
  description  = "Service account used by Cloud Run service with minimal required permissions"
}

# Cloud Run Service with security best practices
resource "google_cloud_run_v2_service" "main" {
  name     = local.service_name
  location = var.gcp_region
  project  = var.project_id

  description = "Cloud Run service for ${var.environment} ${var.app_name}"

  labels = local.common_labels

  template {
    # Set revision suffix for proper versioning
    revision = "${local.service_name}-${formatdate("YYYYMMDD-hhmm", timestamp())}"

    labels = local.common_labels

    # Scaling configuration
    scaling {
      # Aggressive cost optimization with scale-to-zero
      min_instance_count = 0  # Scale to zero for maximum cost savings
      max_instance_count = var.max_instances
    }

    # VPC Access for security
    vpc_access {
      network_interfaces {
        network    = var.vpc_name
        subnetwork = var.private_subnet_names[0]
      }
      # Use VPC egress for all traffic - more secure
      egress = "ALL_TRAFFIC"
    }

    # Service account with minimal permissions
    service_account = google_service_account.cloud_run.email

    # Security context - run as non-root user
    # In GCP Cloud Run, containers run as non-root by default
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      name  = var.app_name
      image = var.container_image

      ports {
        name           = "http1"
        container_port = var.container_port
      }

      # Resource limits
      resources {
        limits = {
          cpu    = var.service_cpu
          memory = var.service_memory
        }
        cpu_idle          = true
        startup_cpu_boost = false
      }

      # Environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      # Health check probes
      startup_probe {
        initial_delay_seconds = 10
        timeout_seconds      = 5
        period_seconds       = 10
        failure_threshold    = 3

        http_get {
          path = "/health"
          port = var.container_port
        }
      }

      liveness_probe {
        initial_delay_seconds = 30
        timeout_seconds      = 5
        period_seconds       = 30
        failure_threshold    = 3

        http_get {
          path = "/health"
          port = var.container_port
        }
      }
    }
  }

  # Traffic configuration
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.cloud_run_api,
    google_project_service.vpc_access_api
  ]
}

# Enable required APIs
resource "google_project_service" "cloud_run_api" {
  project = var.project_id
  service = "run.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy        = false
}

resource "google_project_service" "vpc_access_api" {
  project = var.project_id
  service = "vpcaccess.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy        = false
}

# IAM policy for service account - minimal permissions
resource "google_project_iam_member" "cloud_run_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_metrics" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Global Load Balancer for HTTPS termination and security
resource "google_compute_global_address" "lb_ip" {
  name         = "${var.environment}-${var.app_name}-lb-ip"
  address_type = "EXTERNAL"
  description  = "External IP for ${var.environment} ${var.app_name} load balancer"
}

# Managed SSL Certificate
resource "google_compute_managed_ssl_certificate" "lb_cert" {
  name = "${var.environment}-${var.app_name}-cert"

  managed {
    domains = ["${var.environment}-${var.app_name}.example.com"] # Replace with your actual domain
  }

  description = "Managed SSL certificate for ${var.environment} ${var.app_name}"

  lifecycle {
    create_before_destroy = true
  }
}

# Health check for load balancer
resource "google_compute_health_check" "cloud_run" {
  name                = "${var.environment}-${var.app_name}-health-check"
  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
  description        = "Health check for ${var.environment} ${var.app_name}"

  http_health_check {
    port               = var.container_port
    request_path       = "/health"
    proxy_header       = "NONE"
    response           = "healthy"
  }

  log_config {
    enable = true
  }
}

# Backend service
resource "google_compute_backend_service" "cloud_run" {
  name                    = "${var.environment}-${var.app_name}-backend"
  protocol                = "HTTP"
  port_name               = "http"
  timeout_sec             = 30
  enable_cdn              = false
  load_balancing_scheme   = "EXTERNAL_MANAGED"
  health_checks          = [google_compute_health_check.cloud_run.id]

  description = "Backend service for ${var.environment} ${var.app_name}"

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run.id

    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  # Attach Cloud Armor security policy
  security_policy = google_compute_security_policy.policy.id

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # Connection draining
  connection_draining_timeout_sec = 300

  # Session affinity
  session_affinity = "NONE"

  # Circuit breakers
  outlier_detection {
    consecutive_errors = 5
    interval {
      seconds = 30
    }
    base_ejection_time {
      seconds = 30
    }
    max_ejection_percent = 50
  }
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloud_run" {
  name                  = "${var.environment}-${var.app_name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region

  description = "Network endpoint group for ${var.environment} ${var.app_name}"

  cloud_run {
    service = google_cloud_run_v2_service.main.name
  }
}

# URL Map
resource "google_compute_url_map" "cloud_run" {
  name            = "${var.environment}-${var.app_name}-url-map"
  default_service = google_compute_backend_service.cloud_run.id
  description     = "URL map for ${var.environment} ${var.app_name}"

  # Add security headers
  header_action {
    response_headers_to_add {
      header_name  = "X-Content-Type-Options"
      header_value = "nosniff"
      replace      = true
    }
    response_headers_to_add {
      header_name  = "X-Frame-Options"
      header_value = "DENY"
      replace      = true
    }
    response_headers_to_add {
      header_name  = "X-XSS-Protection"
      header_value = "1; mode=block"
      replace      = true
    }
    response_headers_to_add {
      header_name  = "Strict-Transport-Security"
      header_value = "max-age=31536000; includeSubDomains"
      replace      = true
    }
    response_headers_to_add {
      header_name  = "Referrer-Policy"
      header_value = "strict-origin-when-cross-origin"
      replace      = true
    }
  }
}

# HTTPS Proxy
resource "google_compute_target_https_proxy" "cloud_run" {
  name             = "${var.environment}-${var.app_name}-https-proxy"
  url_map          = google_compute_url_map.cloud_run.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_cert.id]
  description      = "HTTPS proxy for ${var.environment} ${var.app_name}"

  # Use modern TLS policy
  ssl_policy = google_compute_ssl_policy.modern.id
}

# Modern SSL Policy
resource "google_compute_ssl_policy" "modern" {
  name            = "${var.environment}-${var.app_name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
  description     = "Modern SSL policy for ${var.environment} ${var.app_name}"
}

# Global Forwarding Rule for HTTPS
resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.environment}-${var.app_name}-https-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.cloud_run.id
  ip_address            = google_compute_global_address.lb_ip.id
  description           = "HTTPS forwarding rule for ${var.environment} ${var.app_name}"
}

# HTTP to HTTPS Redirect
resource "google_compute_url_map" "redirect" {
  name        = "${var.environment}-${var.app_name}-redirect-map"
  description = "HTTP to HTTPS redirect for ${var.environment} ${var.app_name}"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name        = "${var.environment}-${var.app_name}-http-proxy"
  url_map     = google_compute_url_map.redirect.id
  description = "HTTP proxy for redirecting to HTTPS"
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.environment}-${var.app_name}-http-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
  ip_address            = google_compute_global_address.lb_ip.id
  description           = "HTTP forwarding rule for redirect to HTTPS"
}

# Cloud Monitoring Uptime Check
resource "google_monitoring_uptime_check_config" "cloud_run" {
  display_name = "${var.environment}-${var.app_name}-uptime-check"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = google_compute_global_address.lb_ip.address
    }
  }

  content_matchers {
    content = "healthy"
    matcher = "CONTAINS_STRING"
  }
}

# Cloud Armor Security Policy for comprehensive protection
resource "google_compute_security_policy" "policy" {
  name = "${var.environment}-${var.app_name}-security-policy"
  description = "Cloud Armor security policy for ${var.environment} ${var.app_name}"

  # Rate limiting rule
  rule {
    action   = "rate_based_ban"
    priority = "100"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 300
    }
    description = "Rate limit rule - 100 requests per minute per IP"
  }

  # XSS attack protection
  rule {
    action   = "deny(403)"
    priority = "200"
    match {
      expr {
        expression = "origin.region_code == 'CN' || origin.region_code == 'RU' || origin.region_code == 'KP'"
      }
    }
    description = "Block traffic from specific countries"
  }

  # SQL injection protection
  rule {
    action   = "deny(403)"
    priority = "300"
    match {
      expr {
        expression = "has(request.headers['user-agent']) && request.headers['user-agent'].contains('sqlmap')"
      }
    }
    description = "Block SQL injection tools"
  }

  # Block known bad bot user agents
  rule {
    action   = "deny(403)"
    priority = "400"
    match {
      expr {
        expression = "has(request.headers['user-agent']) && (request.headers['user-agent'].contains('bot') || request.headers['user-agent'].contains('crawler') || request.headers['user-agent'].contains('spider')) && !request.headers['user-agent'].contains('Googlebot') && !request.headers['user-agent'].contains('Bingbot')"
      }
    }
    description = "Block malicious bots but allow legitimate search engines"
  }

  # Log4j vulnerability protection (CVE-2021-44228)
  rule {
    action   = "deny(403)"
    priority = "900"
    match {
      expr {
        expression = "request.headers['user-agent'].contains('${jndi:') || request.url_path.contains('${jndi:') || request.query.contains('${jndi:') || request.body.contains('${jndi:')"
      }
    }
    description = "Block Log4j JNDI injection attempts"
  }

  # Additional Log4j protection for URL-encoded payloads
  rule {
    action   = "deny(403)"
    priority = "901"
    match {
      expr {
        expression = "request.url_path.contains('%24%7bjndi') || request.query.contains('%24%7bjndi') || request.url_path.contains('$%7bjndi') || request.query.contains('$%7bjndi')"
      }
    }
    description = "Block URL-encoded Log4j JNDI injection attempts"
  }

  # Allow legitimate traffic
  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Allow all legitimate traffic"
  }

  # Default deny rule
  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default deny rule"
  }

  # Advanced DDoS protection
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }

  # Enable advanced JSON parsing
  advanced_options_config {
    json_parsing = "STANDARD"
    log_level    = "VERBOSE"
  }
}

# Cost Optimization: Monitoring and Budgets
resource "google_billing_budget" "cloud_run_budget" {
  count           = var.environment == "prod" ? 1 : 0  # Only for production
  billing_account = var.billing_account_id
  display_name    = "${var.environment}-${var.app_name}-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
    services = [
      "services/E5F0-40B9-87C7",  # Cloud Run service
      "services/95FF-2EF5-5EA1",  # Compute Engine (for load balancer)
    ]
    labels = {
      environment = var.environment
      project     = var.project_name
    }
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "75"  # $75 monthly budget for GCP
    }
  }

  threshold_rules {
    threshold_percent = 0.8  # 80% threshold
    spend_basis      = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0  # 100% threshold
    spend_basis      = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = var.budget_alert_channels
    disable_default_iam_recipients   = true
  }
}

# Cloud Monitoring Alert Policy for High Resource Usage
resource "google_monitoring_alert_policy" "cloud_run_high_usage" {
  count        = var.environment == "prod" ? 1 : 0
  display_name = "${var.environment}-${var.app_name}-high-cpu-usage"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run CPU utilization"

    condition_threshold {
      filter         = "resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${google_cloud_run_v2_service.app.name}\""
      duration       = "300s"
      comparison     = "COMPARISON_GT"
      threshold_value = 80

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.budget_alert_channels

  alert_strategy {
    auto_close = "1800s"  # 30 minutes
  }
}