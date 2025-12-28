# Container Registry with Security Enhancements
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.environment, "-", "")}${replace(var.project_name, "-", "")}acr"
  resource_group_name = var.resource_group_name
  location           = var.resource_group_location
  sku                = "Premium"
  admin_enabled      = false

  # Enable security features
  public_network_access_enabled    = false
  quarantine_policy_enabled        = true
  data_endpoint_enabled            = true  # Enable dedicated data endpoints for enhanced security
  retention_policy {
    days    = 30
    enabled = true
  }

  trust_policy {
    enabled = true
  }

  # Enable encryption
  encryption {
    enabled            = true
    key_vault_key_id   = azurerm_key_vault_key.acr.id
    identity_client_id = azurerm_user_assigned_identity.acr.client_id
  }

  # Enable zone redundancy for high availability
  zone_redundancy_enabled = true

  # Geo-replication for disaster recovery
  georeplications {
    location                = "West US 2"
    zone_redundancy_enabled = true
    tags = {
      Environment = var.environment
      Project     = var.project_name
      Replica     = "west-us-2"
    }
  }

  georeplications {
    location                = "East US 2"
    zone_redundancy_enabled = true
    tags = {
      Environment = var.environment
      Project     = var.project_name
      Replica     = "east-us-2"
    }
  }

  # Network rules
  network_rule_set {
    default_action = "Deny"

    virtual_network {
      action    = "Allow"
      subnet_id = var.private_subnet_id
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# User Assigned Identity for ACR
resource "azurerm_user_assigned_identity" "acr" {
  resource_group_name = var.resource_group_name
  location           = var.resource_group_location
  name               = "${var.environment}-${var.app_name}-acr-identity"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Key Vault for ACR encryption
resource "azurerm_key_vault" "acr" {
  name                = "${var.environment}-${var.app_name}-kv"
  location           = var.resource_group_location
  resource_group_name = var.resource_group_name
  tenant_id          = data.azurerm_client_config.current.tenant_id
  sku_name           = "premium"

  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  # Network ACLs
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    virtual_network_subnet_ids = [var.private_subnet_id]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.acr.principal_id

    key_permissions = [
      "Get", "Create", "Delete", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Import", "Update", "Purge", "Recover"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.aci.principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

resource "azurerm_key_vault_key" "acr" {
  name         = "${var.environment}-${var.app_name}-acr-key"
  key_vault_id = azurerm_key_vault.acr.id
  key_type     = "RSA-HSM"  # Use HSM-backed key for enhanced security
  key_size     = 2048

  # Set expiration date for security compliance (2 years from now)
  expiration_date = timeadd(timestamp(), "17520h") # 2 years = 730 days * 24 hours

  key_opts = [
    "decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# SSL Certificate in Key Vault for Application Gateway
resource "azurerm_key_vault_certificate" "ssl" {
  name         = "${var.environment}-${var.app_name}-ssl-cert"
  key_vault_id = azurerm_key_vault.acr.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=${var.environment}-${var.app_name}.example.com"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [
          "${var.environment}-${var.app_name}.example.com"
        ]
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Secure Environment Variables in Key Vault
resource "azurerm_key_vault_secret" "env_vars" {
  for_each        = var.environment_variables
  name            = "env-${each.key}"
  value           = each.value
  key_vault_id    = azurerm_key_vault.acr.id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "8760h")  # 1 year expiration

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
    Purpose     = "container-env-var"
  }
}

data "azurerm_client_config" "current" {}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = "${var.environment}-${var.app_name}-kv-pe"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_subnet_id

  private_service_connection {
    name                           = "${var.environment}-${var.app_name}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.acr.id
    subresource_names             = ["vault"]
    is_manual_connection          = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "${var.environment}-${var.app_name}-kv-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = var.vnet_id

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Application Gateway Public IP
resource "azurerm_public_ip" "app_gateway" {
  name                = "${var.environment}-${var.app_name}-appgw-pip"
  resource_group_name = var.resource_group_name
  location           = var.resource_group_location
  allocation_method   = "Static"
  sku                = "Standard"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "${var.environment}-${var.app_name}-appgw"
  resource_group_name = var.resource_group_name
  location           = var.resource_group_location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  # WAF Configuration
  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"

    disabled_rule_group {
      rule_group_name = "REQUEST-932-APPLICATION-ATTACK-RCE"
      rules           = [932100, 932110]
    }

    # File upload limits
    file_upload_limit_mb = 100

    # Request body inspection
    request_body_check = true
    max_request_body_size_kb = 128

    # Exclusions for specific paths if needed
    exclusion {
      match_variable          = "RequestArgNames"
      selector_match_operator = "StartsWith"
      selector                = "api"
    }
  }

  gateway_ip_configuration {
    name      = "app-gateway-ip-configuration"
    subnet_id = var.public_subnet_id
  }

  # SSL Certificate from Key Vault for enhanced security
  ssl_certificate {
    name                = "app-gateway-ssl-cert"
    key_vault_secret_id = azurerm_key_vault_certificate.ssl.secret_id
  }

  frontend_port {
    name = "frontend-port-https"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  backend_address_pool {
    name = "backend-pool"
  }

  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = var.container_port
    protocol              = "Http"
    request_timeout       = 60

    probe_name = "health-probe"
  }

  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-ip-configuration"
    frontend_port_name             = "frontend-port-https"
    protocol                       = "Https"
    ssl_certificate_name           = "app-gateway-ssl-cert"
  }

  # SSL Policy for secure protocols
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"  # Most secure predefined policy
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "backend-http-settings"
    priority                   = 1
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }

  depends_on = [azurerm_public_ip.app_gateway]
}

# User Assigned Identity for Container Instances
resource "azurerm_user_assigned_identity" "aci" {
  resource_group_name = var.resource_group_name
  location           = var.resource_group_location
  name               = "${var.environment}-${var.app_name}-aci-identity"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Container Group with Cost Optimization
resource "azurerm_container_group" "main" {
  count               = var.min_instance_count  # Start with minimum instances
  name                = "${var.environment}-${var.app_name}-aci-${count.index + 1}"
  location           = var.resource_group_location
  resource_group_name = var.resource_group_name
  ip_address_type    = "Private"
  subnet_ids         = [var.private_subnet_id]
  os_type            = "Linux"

  # Configure managed identity for security
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aci.id]
  }

  # Enable auto-restart for cost-effective fault tolerance
  restart_policy = "Always"

  container {
    name   = var.app_name
    image  = var.container_image
    cpu    = var.container_cpu
    memory = var.container_memory

    ports {
      port     = var.container_port
      protocol = "TCP"
    }

    # Use secure environment variables instead of plain text
    secure_environment_variables = {
      for key, value in var.environment_variables : key => azurerm_key_vault_secret.env_vars[key].value
    }

    liveness_probe {
      http_get {
        path   = "/health"
        port   = var.container_port
        scheme = "Http"
      }
      initial_delay_seconds = 30
      period_seconds        = 10
      failure_threshold     = 3
      success_threshold     = 1
      timeout_seconds       = 5
    }

    readiness_probe {
      http_get {
        path   = "/health"
        port   = var.container_port
        scheme = "Http"
      }
      initial_delay_seconds = 5
      period_seconds        = 5
      failure_threshold     = 3
      success_threshold     = 1
      timeout_seconds       = 5
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
  }
}

# Associate Container Groups with Application Gateway Backend Pool
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "main" {
  count                   = var.min_instance_count  # Use minimum count for cost optimization
  network_interface_id    = azurerm_container_group.main[count.index].network_interface_ids[0]
  ip_configuration_name   = "internal"
  backend_address_pool_id = tolist(azurerm_application_gateway.main.backend_address_pool)[0].id
}

# Log Analytics Workspace - Cost Optimized
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.environment}-${var.app_name}-law"
  location           = var.resource_group_location
  resource_group_name = var.resource_group_name
  sku                = "PerGB2018"
  retention_in_days   = 30  # Optimized retention for cost

  # Enable cost optimization features
  daily_quota_gb                     = 1  # 1GB daily limit to control costs
  internet_ingestion_enabled         = false
  internet_query_enabled             = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Cloud       = "Azure"
    Purpose     = "cost-optimized"
  }
}

# Azure Monitor Action Group for Cost Alerts
resource "azurerm_monitor_action_group" "cost_alerts" {
  name                = "${var.environment}-${var.app_name}-cost-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "CostAlert"

  email_receiver {
    name          = "cost-alert-email"
    email_address = var.budget_alert_email
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "cost-monitoring"
  }
}

# Azure Budget for Cost Control
resource "azurerm_consumption_budget_resource_group" "main" {
  count               = var.environment == "prod" ? 1 : 0  # Only for production
  name                = "${var.environment}-${var.app_name}-budget"
  resource_group_id   = var.resource_group_id

  amount     = 150  # $150 monthly budget for Azure resources
  time_grain = "Monthly"

  time_period {
    start_date = "2024-01-01T00:00:00Z"
  }

  filter {
    dimension {
      name = "ResourceGroupName"
      values = [var.resource_group_name]
    }
  }

  notification {
    enabled        = true
    threshold      = 80  # Alert at 80% of budget
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [var.budget_alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100  # Alert at 100% of budget
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = [var.budget_alert_email]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "cost-control"
  }
}