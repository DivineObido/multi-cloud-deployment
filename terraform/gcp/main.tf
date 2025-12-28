provider "google" {
  project = var.project_id
  region  = var.gcp_region

  # Enable request logging for security monitoring
  request_timeout = "60s"

  # Default labels for all resources
  default_labels = {
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
    cloud       = "gcp"
  }
}

# Enable required Google Cloud APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "run.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "vpcaccess.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy        = false
}

# VPC Module
module "vpc" {
  source = "../modules/gcp/vpc"

  project_id             = var.project_id
  gcp_region             = var.gcp_region
  zones                  = var.zones
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  environment           = var.environment
  project_name          = var.project_name

  depends_on = [google_project_service.required_apis]
}

# Cloud Run Module
module "cloud_run" {
  source = "../modules/gcp/cloud-run"

  project_id            = var.project_id
  gcp_region            = var.gcp_region
  vpc_name              = module.vpc.vpc_name
  private_subnet_names  = module.vpc.private_subnet_names
  environment          = var.environment
  project_name         = var.project_name
  app_name             = var.app_name
  container_image      = var.container_image
  container_port       = var.container_port
  service_cpu          = var.service_cpu
  service_memory       = var.service_memory
  min_instances        = var.min_instances
  max_instances        = var.max_instances
  environment_variables = var.environment_variables

  depends_on = [
    module.vpc,
    google_project_service.required_apis
  ]
}

# Cloud Monitoring Notification Channel (for alerts)
resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.environment}-${var.app_name}-email-notifications"
  type         = "email"

  labels = {
    email_address = "admin@example.com" # Replace with your email
  }

  description = "Email notification channel for ${var.environment} ${var.app_name} alerts"
}

# Alerting Policy for High Error Rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "${var.environment}-${var.app_name}-high-error-rate"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "High 5xx error rate"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields = [
          "resource.labels.service_name",
          "resource.labels.revision_name"
        ]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    content = "High error rate detected for ${var.environment} ${var.app_name}"
    mime_type = "text/markdown"
  }
}

# Alerting Policy for High Latency
resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "${var.environment}-${var.app_name}-high-latency"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "High request latency"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2000

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields = [
          "resource.labels.service_name"
        ]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    content = "High latency detected for ${var.environment} ${var.app_name}"
    mime_type = "text/markdown"
  }
}

# Cloud Logging Metric for Security Events
resource "google_logging_metric" "security_events" {
  name   = "${var.environment}-${var.app_name}-security-events"
  filter = "resource.type=\"cloud_run_revision\" AND (textPayload:\"unauthorized\" OR textPayload:\"forbidden\" OR httpRequest.status>=400)"

  label_extractors = {
    "service_name" = "EXTRACT(resource.labels.service_name)"
    "status_code"  = "EXTRACT(httpRequest.status)"
  }

  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "Security Events"
  }
}

# Alerting Policy for Security Events
resource "google_monitoring_alert_policy" "security_events" {
  display_name = "${var.environment}-${var.app_name}-security-events"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Security events detected"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.security_events.name}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    content = "Security events detected for ${var.environment} ${var.app_name}"
    mime_type = "text/markdown"
  }
}

# External Health Check for Multi-Cloud Monitoring
resource "google_monitoring_uptime_check_config" "external_health" {
  display_name = "${var.environment}-${var.app_name}-external-health"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    headers = {
      "User-Agent" = "GoogleStackdriverMonitoring-UptimeChecks"
    }

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = module.cloud_run.load_balancer_ip
    }
  }

  content_matchers {
    content = "healthy"
    matcher = "CONTAINS_STRING"
  }

  # Check from multiple locations for better coverage
  selected_regions = [
    "USA",
    "EUROPE",
    "ASIA_PACIFIC"
  ]
}

# Dashboard for monitoring
resource "google_monitoring_dashboard" "main" {
  dashboard_json = jsonencode({
    displayName = "${var.environment} ${var.app_name} Dashboard"

    gridLayout = {
      widgets = [
        {
          title = "Request Count"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                  aggregation = {
                    alignmentPeriod = "60s"
                    perSeriesAligner = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "Requests/sec"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Response Latency"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                  aggregation = {
                    alignmentPeriod = "60s"
                    perSeriesAligner = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_PERCENTILE_95"
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "Latency (ms)"
              scale = "LINEAR"
            }
          }
        }
      ]
    }
  })
}

# Log-based metrics for detailed monitoring
resource "google_logging_metric" "request_count" {
  name   = "${var.environment}-${var.app_name}-request-count"
  filter = "resource.type=\"cloud_run_revision\" AND httpRequest.requestUrl!=\"\""

  label_extractors = {
    "method"      = "EXTRACT(httpRequest.requestMethod)"
    "status_code" = "EXTRACT(httpRequest.status)"
    "service"     = "EXTRACT(resource.labels.service_name)"
  }

  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "HTTP Requests"
  }
}

# Log sink for security analysis (optional but recommended)
resource "google_logging_project_sink" "security_sink" {
  name        = "${var.environment}-${var.app_name}-security-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.security_logs.name}"

  # Filter for security-relevant logs
  filter = <<EOF
resource.type="cloud_run_revision"
AND (
  httpRequest.status>=400
  OR textPayload:"error"
  OR textPayload:"unauthorized"
  OR textPayload:"forbidden"
  OR textPayload:"attack"
)
EOF

  unique_writer_identity = true
}

# Security logs bucket
resource "google_storage_bucket" "security_logs" {
  name          = "${var.project_id}-${var.environment}-${var.app_name}-security-logs"
  location      = "US"
  force_destroy = false

  # Retention policy with bucket lock for compliance
  retention_policy {
    retention_period = 7776000  # 90 days in seconds
    is_locked        = true
  }

  # Lifecycle management
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  # Versioning
  versioning {
    enabled = true
  }

  # Encryption
  encryption {
    default_kms_key_name = google_kms_crypto_key.security_logs.id
  }

  # Public access prevention
  public_access_prevention = "enforced"

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Enable access logging
  logging {
    log_bucket        = google_storage_bucket.access_logs.name
    log_object_prefix = "security-logs-access/"
  }
}

# Separate bucket for access logs
resource "google_storage_bucket" "access_logs" {
  name          = "${var.project_id}-${var.environment}-${var.app_name}-access-logs"
  location      = "US"
  force_destroy = false

  # Retention policy with bucket lock for access logs
  retention_policy {
    retention_period = 2592000  # 30 days in seconds
    is_locked        = true
  }

  # Enable versioning
  versioning {
    enabled = true
  }

  # Public access prevention
  public_access_prevention = "enforced"

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Access logging for the access logs bucket
  logging {
    log_bucket        = google_storage_bucket.audit_logs.name
    log_object_prefix = "access-logs-audit/"
  }

  # Lifecycle management for access logs
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  # Lifecycle rule for old versions
  lifecycle_rule {
    condition {
      age                   = 7
      with_state           = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

# Audit logs bucket for logging the access logs bucket
resource "google_storage_bucket" "audit_logs" {
  name          = "${var.project_id}-${var.environment}-${var.app_name}-audit-logs"
  location      = "US"
  force_destroy = false

  # Retention policy with bucket lock for audit logs
  retention_policy {
    retention_period = 7776000  # 90 days in seconds
    is_locked        = true
  }

  # Enable versioning
  versioning {
    enabled = true
  }

  # Public access prevention
  public_access_prevention = "enforced"

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Access logging for the audit logs bucket (final tier)
  logging {
    log_bucket        = google_storage_bucket.final_audit_logs.name
    log_object_prefix = "audit-logs-final/"
  }

  # Extended lifecycle for audit logs
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}

# Final audit logs bucket (for logging the audit logs bucket)
resource "google_storage_bucket" "final_audit_logs" {
  name          = "${var.project_id}-${var.environment}-${var.app_name}-final-audit"
  location      = "US"
  force_destroy = false

  # Retention policy with bucket lock for final audit logs
  retention_policy {
    retention_period = 31536000  # 365 days (1 year) in seconds
    is_locked        = true
  }

  # Enable versioning
  versioning {
    enabled = true
  }

  # Public access prevention
  public_access_prevention = "enforced"

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Access logging for final audit logs (logs to a separate ultimate logging bucket)
  logging {
    log_bucket        = google_storage_bucket.ultimate_audit_logs.name
    log_object_prefix = "final-audit-access/"
  }

  # Extended lifecycle for final audit logs
  lifecycle_rule {
    condition {
      age = 365  # Keep final audit logs for 1 year
    }
    action {
      type = "Delete"
    }
  }
}

# Ultimate audit logs bucket (final destination - no further logging to avoid circular dependency)
resource "google_storage_bucket" "ultimate_audit_logs" {
  name          = "${var.project_id}-${var.environment}-${var.app_name}-ultimate-audit"
  location      = "US"
  force_destroy = false

  # Retention policy with bucket lock for ultimate audit logs
  retention_policy {
    retention_period = 63072000  # 2 years in seconds for ultimate logging
    is_locked        = true
  }

  # Enable versioning
  versioning {
    enabled = true
  }

  # Public access prevention
  public_access_prevention = "enforced"

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Extended lifecycle for ultimate audit logs
  lifecycle_rule {
    condition {
      age = 730  # Keep ultimate audit logs for 2 years
    }
    action {
      type = "Delete"
    }
  }
}

# KMS key for security logs encryption
resource "google_kms_key_ring" "security" {
  name     = "${var.environment}-${var.app_name}-security-keyring"
  location = "global"
}

resource "google_kms_crypto_key" "security_logs" {
  name     = "${var.environment}-${var.app_name}-security-logs-key"
  key_ring = google_kms_key_ring.security.id

  purpose = "ENCRYPT_DECRYPT"

  # Enable automatic key rotation every 90 days
  rotation_period = "7776000s" # 90 days in seconds

  lifecycle {
    prevent_destroy = true
  }

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }
}

# IAM binding for log sink
resource "google_storage_bucket_iam_binding" "security_logs_sink" {
  bucket = google_storage_bucket.security_logs.name
  role   = "roles/storage.objectCreator"
  members = [
    google_logging_project_sink.security_sink.writer_identity,
  ]
}