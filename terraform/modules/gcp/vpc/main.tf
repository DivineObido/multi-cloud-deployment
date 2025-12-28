# Local values for consistent naming and tagging
locals {
  common_labels = {
    environment   = var.environment
    project       = var.project_name
    managed_by    = "terraform"
    cloud         = "gcp"
    created_date  = formatdate("YYYY-MM-DD", timestamp())
  }
}

# VPC Network with security best practices
resource "google_compute_network" "main" {
  name                            = "${var.environment}-${var.project_name}-vpc"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
  description                     = "VPC network for ${var.environment} environment"

  # Enable flow logs for security monitoring
  # This is handled at the subnetwork level in GCP
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "main" {
  name    = "${var.environment}-${var.project_name}-router"
  region  = var.gcp_region
  network = google_compute_network.main.id

  description = "Cloud Router for NAT Gateway"

  bgp {
    asn = 64514
  }
}

# Public Subnets
resource "google_compute_subnetwork" "public" {
  count = length(var.public_subnet_cidrs)

  name                     = "${var.environment}-${var.project_name}-public-subnet-${count.index + 1}"
  ip_cidr_range            = var.public_subnet_cidrs[count.index]
  region                   = var.gcp_region
  network                  = google_compute_network.main.id
  description             = "Public subnet ${count.index + 1} for ${var.environment} environment"

  # Enable private Google access for security
  private_ip_google_access = true

  # Enable flow logs for security monitoring
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata            = "INCLUDE_ALL_METADATA"
  }

  # Secondary IP ranges can be added for GKE if needed
  # secondary_ip_range {
  #   range_name    = "pods"
  #   ip_cidr_range = "10.2.64.0/18"
  # }
  # secondary_ip_range {
  #   range_name    = "services"
  #   ip_cidr_range = "10.2.128.0/20"
  # }
}

# Private Subnets
resource "google_compute_subnetwork" "private" {
  count = length(var.private_subnet_cidrs)

  name                     = "${var.environment}-${var.project_name}-private-subnet-${count.index + 1}"
  ip_cidr_range            = var.private_subnet_cidrs[count.index]
  region                   = var.gcp_region
  network                  = google_compute_network.main.id
  description             = "Private subnet ${count.index + 1} for ${var.environment} environment"

  # Enable private Google access for security
  private_ip_google_access = true

  # Enable flow logs for security monitoring
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata            = "INCLUDE_ALL_METADATA"
  }
}

# Cloud NAT for private subnet internet access
resource "google_compute_router_nat" "main" {
  name                               = "${var.environment}-${var.project_name}-nat"
  router                             = google_compute_router.main.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                           = google_compute_address.nat.*.self_link
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  # Apply NAT to private subnets only
  dynamic "subnetwork" {
    for_each = google_compute_subnetwork.private
    content {
      name                    = subnetwork.value.id
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  # Enable logging for security monitoring
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Auto-scale NAT IPs based on usage
  min_ports_per_vm = 64
  max_ports_per_vm = 65536
}

# Static IP addresses for NAT Gateway
resource "google_compute_address" "nat" {
  count = 2

  name         = "${var.environment}-${var.project_name}-nat-ip-${count.index + 1}"
  address_type = "EXTERNAL"
  region       = var.gcp_region
  description  = "NAT Gateway IP ${count.index + 1} for ${var.environment} environment"
}

# Firewall Rules - Restrictive by default, following principle of least privilege

# Allow internal VPC communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-${var.project_name}-allow-internal"
  network = google_compute_network.main.name

  description = "Allow internal VPC communication"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr]
  target_tags   = ["internal"]
}

# Allow SSH from specific ranges (replace with your IP ranges)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.environment}-${var.project_name}-allow-ssh"
  network = google_compute_network.main.name

  description = "Allow SSH from authorized ranges"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Restrict to specific IP ranges - replace with your actual management IPs
  source_ranges = ["35.235.240.0/20"] # Google Cloud IAP range for secure access
  target_tags   = ["ssh-allowed"]
}

# Allow HTTP/HTTPS to public subnets (for load balancer health checks)
resource "google_compute_firewall" "allow_lb_health_checks" {
  name    = "${var.environment}-${var.project_name}-allow-lb-health-checks"
  network = google_compute_network.main.name

  description = "Allow load balancer health checks"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  # Google Cloud Load Balancer health check ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]
  target_tags = ["lb-health-check"]
}

# Allow HTTPS from anywhere to public-facing services
resource "google_compute_firewall" "allow_https_public" {
  name    = "${var.environment}-${var.project_name}-allow-https-public"
  network = google_compute_network.main.name

  description = "Allow HTTPS from internet to public services"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public-https"]
}

# Deny all other inbound traffic (explicit deny)
resource "google_compute_firewall" "deny_all" {
  name    = "${var.environment}-${var.project_name}-deny-all"
  network = google_compute_network.main.name

  description = "Deny all other inbound traffic"
  direction   = "INGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create default route to internet gateway for public subnets
resource "google_compute_route" "public_internet_gateway" {
  name             = "${var.environment}-${var.project_name}-public-internet-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.main.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  description      = "Route to internet gateway for public subnets"

  tags = ["public-internet"]
}

# VPC Flow Logs are enabled on subnets above
# Cloud Audit Logs should be enabled at the project level