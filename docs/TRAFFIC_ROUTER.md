# Traffic Router - Intelligent Multi-Cloud Routing

This module provides intelligent traffic routing between AWS and Azure deployments using Cloudflare's Load Balancer with health checks and performance-based routing.

## Features

- **Health-based Failover**: Automatically routes traffic away from unhealthy endpoints
- **Performance-based Routing**: Considers response times when distributing traffic
- **Cost-aware Routing**: Takes into account cloud costs for optimal routing
- **Geographic Steering**: Routes users to the closest/best performing cloud region
- **Session Affinity**: Maintains user sessions on the same cloud when needed

## Architecture

```
Internet → Cloudflare Load Balancer → {
    AWS Pool (ECS + ALB)
    Azure Pool (ACI + App Gateway)
}
```

## Components

### DNS-based Load Balancing
- **Cloudflare Load Balancer**: Primary traffic distribution
- **Health Monitors**: Continuous health checking of both clouds
- **Pool Management**: Separate pools for AWS and Azure
- **Geographic Routing**: Region-based traffic steering

### Health Checks
- **AWS Route53 Health Checks**: Monitor AWS ALB endpoints
- **Cloudflare Health Monitors**: Monitor Azure App Gateway endpoints
- **Custom Health Endpoints**: Application-level health validation

### Intelligent Routing Logic
- **Health Priority**: Unhealthy endpoints receive no traffic
- **Performance Weighting**: Faster endpoints receive more traffic
- **Cost Optimization**: Cheaper clouds get slight preference
- **Geographic Preference**: Regional routing based on user location

## Setup Instructions

### 1. Prerequisites

- Cloudflare account with API access
- Domain registered with Cloudflare DNS
- AWS and Azure infrastructure deployed
- Terraform installed

### 2. Configuration

1. Copy the example configuration:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Update the configuration with your values:
   ```hcl
   domain_name          = "yourdomain.com"
   subdomain           = "app"
   aws_endpoint        = "http://your-aws-alb.elb.amazonaws.com"
   azure_endpoint      = "http://your-azure-appgw-ip"
   cloudflare_api_token = "your-cloudflare-api-token"
   ```

3. Get Cloudflare API Token:
   - Go to Cloudflare Dashboard → My Profile → API Tokens
   - Create token with Zone:Edit permissions for your domain

### 3. Deploy Traffic Router

```bash
cd traffic-router
terraform init
terraform plan
terraform apply
```

### 4. Integrate with CI/CD

The `update-routing.sh` script is automatically called by Jenkins after deployments to update routing based on current health and performance metrics.

## Routing Logic

### Health-based Routing
- **Both Healthy**: Traffic distributed based on performance and cost
- **One Unhealthy**: All traffic routed to healthy endpoint
- **Both Unhealthy**: Maintains current routing, alerts triggered

### Performance Metrics
- Response time measurement
- Success rate monitoring
- Geographic latency consideration

### Cost Factors
- Real-time cost analysis from cloud billing APIs
- Preference weighting based on current costs
- Cost thresholds for automatic switching

## Monitoring and Alerting

### Health Check Monitoring
```bash
# View health check status
terraform output aws_health_check_id
terraform output azure_health_check_id

# Check routing logs
tail -f traffic-router/routing-updates.log
```

### Performance Metrics
- Response time tracking
- Availability monitoring
- Geographic performance analysis

## Configuration Options

### Load Balancer Settings
- **Session Affinity**: Maintain user sessions on same cloud
- **Failover Threshold**: Number of failed checks before failover
- **Health Check Interval**: Frequency of health monitoring

### Routing Weights
- **Default**: 50/50 split between clouds
- **Performance**: Adjust based on response times
- **Cost**: Slight preference to cheaper cloud
- **Health**: Automatic failover to healthy endpoints

## Troubleshooting

### Common Issues

1. **Health Checks Failing**
   ```bash
   # Check application endpoints directly
   curl http://your-aws-endpoint/health
   curl http://your-azure-endpoint/health
   ```

2. **Routing Not Updating**
   ```bash
   # Check routing script logs
   tail -f traffic-router/routing-updates.log

   # Manually run routing update
   ./update-routing.sh
   ```

3. **DNS Propagation Issues**
   ```bash
   # Check DNS resolution
   dig app.yourdomain.com
   nslookup app.yourdomain.com
   ```

### Debug Commands

```bash
# Check Cloudflare load balancer status
terraform output cloudflare_load_balancer_id

# View current routing configuration
cat traffic-router/routing-config.json

# Test endpoints manually
curl -v http://app.yourdomain.com/health
```

## Security Considerations

- API tokens stored securely in Terraform variables
- Health check endpoints authenticated
- Traffic encryption via Cloudflare SSL
- Monitoring access restricted to authorized users

## Cost Optimization

The routing system continuously monitors costs and adjusts traffic distribution to minimize expenses while maintaining performance and availability.

### Cost Monitoring
- AWS CloudWatch billing metrics
- Azure Cost Management APIs
- Real-time cost comparison
- Automated cost-based routing adjustments