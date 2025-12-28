#!/bin/bash

# Multi-Cloud Traffic Routing Update Script
# This script is called by Jenkins after deployment to update routing rules

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/routing-updates.log"
CONFIG_FILE="${SCRIPT_DIR}/routing-config.json"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Function to check endpoint health
check_health() {
    local endpoint="$1"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log "Checking health of ${endpoint} (attempt ${attempt}/${max_attempts})"

        if curl -f -s --max-time 10 "${endpoint}/health" > /dev/null 2>&1; then
            log "✓ ${endpoint} is healthy"
            return 0
        fi

        log "✗ ${endpoint} health check failed"
        attempt=$((attempt + 1))
        sleep 5
    done

    log "✗ ${endpoint} is unhealthy after ${max_attempts} attempts"
    return 1
}

# Function to get endpoint performance metrics
get_performance_metrics() {
    local endpoint="$1"
    local response_time

    response_time=$(curl -o /dev/null -s -w "%{time_total}" "${endpoint}/health" 2>/dev/null || echo "999")
    echo "${response_time}"
}

# Function to update Cloudflare load balancer weights
update_cloudflare_weights() {
    local aws_weight="$1"
    local azure_weight="$2"

    log "Updating Cloudflare load balancer weights: AWS=${aws_weight}, Azure=${azure_weight}"

    # Get pool IDs from Terraform outputs
    local aws_pool_id azure_pool_id
    aws_pool_id=$(cd "${SCRIPT_DIR}" && terraform output -raw aws_pool_id 2>/dev/null || echo "")
    azure_pool_id=$(cd "${SCRIPT_DIR}" && terraform output -raw azure_pool_id 2>/dev/null || echo "")

    if [[ -z "${aws_pool_id}" || -z "${azure_pool_id}" ]]; then
        log "✗ Could not get pool IDs from Terraform outputs"
        return 1
    fi

    # Update weights using Cloudflare API
    # Note: This would require the Cloudflare API token and proper API calls
    # For demo purposes, we'll log the intended action
    log "Would update pool weights via Cloudflare API"
    log "AWS Pool ID: ${aws_pool_id}, Weight: ${aws_weight}"
    log "Azure Pool ID: ${azure_pool_id}, Weight: ${azure_weight}"
}

# Function to analyze costs (simplified example)
analyze_costs() {
    local aws_cost azure_cost

    # These would typically come from cloud billing APIs
    # For demo purposes, using placeholder values
    aws_cost=$(echo "scale=4; $(date +%s) % 100 / 100" | bc 2>/dev/null || echo "0.05")
    azure_cost=$(echo "scale=4; $(date +%s) % 150 / 100" | bc 2>/dev/null || echo "0.06")

    log "Current estimated costs: AWS=$${aws_cost}/hour, Azure=$${azure_cost}/hour"

    if (( $(echo "${aws_cost} < ${azure_cost}" | bc -l) )); then
        echo "aws"
    else
        echo "azure"
    fi
}

# Main routing logic
main() {
    log "Starting traffic routing update..."

    # Get endpoints from Terraform outputs or environment variables
    local aws_endpoint azure_endpoint
    aws_endpoint="${AWS_ENDPOINT:-$(cd ../terraform/aws && terraform output -raw aws_endpoint 2>/dev/null || echo "")}"
    azure_endpoint="${AZURE_ENDPOINT:-$(cd ../terraform/azure && terraform output -raw azure_endpoint 2>/dev/null || echo "")}"

    if [[ -z "${aws_endpoint}" || -z "${azure_endpoint}" ]]; then
        log "✗ Could not determine endpoints"
        exit 1
    fi

    log "Monitoring endpoints:"
    log "AWS: ${aws_endpoint}"
    log "Azure: ${azure_endpoint}"

    # Check health of both endpoints
    local aws_healthy=false
    local azure_healthy=false

    if check_health "${aws_endpoint}"; then
        aws_healthy=true
    fi

    if check_health "${azure_endpoint}"; then
        azure_healthy=true
    fi

    # Get performance metrics
    local aws_response_time azure_response_time
    aws_response_time=$(get_performance_metrics "${aws_endpoint}")
    azure_response_time=$(get_performance_metrics "${azure_endpoint}")

    log "Performance metrics:"
    log "AWS response time: ${aws_response_time}s"
    log "Azure response time: ${azure_response_time}s"

    # Analyze costs
    local preferred_cloud
    preferred_cloud=$(analyze_costs)
    log "Cost analysis suggests: ${preferred_cloud}"

    # Determine routing weights based on health, performance, and cost
    local aws_weight=50
    local azure_weight=50

    if [[ "${aws_healthy}" == "true" && "${azure_healthy}" == "true" ]]; then
        log "Both clouds are healthy, applying intelligent routing..."

        # Performance-based routing
        if (( $(echo "${aws_response_time} < ${azure_response_time}" | bc -l) )); then
            aws_weight=70
            azure_weight=30
            log "AWS is faster, increasing AWS weight"
        elif (( $(echo "${azure_response_time} < ${aws_response_time}" | bc -l) )); then
            aws_weight=30
            azure_weight=70
            log "Azure is faster, increasing Azure weight"
        fi

        # Cost-based adjustment
        if [[ "${preferred_cloud}" == "aws" ]]; then
            aws_weight=$((aws_weight + 10))
            azure_weight=$((azure_weight - 10))
            log "AWS is cheaper, slight preference adjustment"
        elif [[ "${preferred_cloud}" == "azure" ]]; then
            aws_weight=$((aws_weight - 10))
            azure_weight=$((azure_weight + 10))
            log "Azure is cheaper, slight preference adjustment"
        fi

    elif [[ "${aws_healthy}" == "true" && "${azure_healthy}" == "false" ]]; then
        log "Azure is unhealthy, routing all traffic to AWS"
        aws_weight=100
        azure_weight=0

    elif [[ "${aws_healthy}" == "false" && "${azure_healthy}" == "true" ]]; then
        log "AWS is unhealthy, routing all traffic to Azure"
        aws_weight=0
        azure_weight=100

    else
        log "✗ Both clouds are unhealthy! Keeping current routing."
        return 1
    fi

    # Normalize weights to ensure they sum to 100
    local total_weight=$((aws_weight + azure_weight))
    if [[ ${total_weight} -gt 0 ]]; then
        aws_weight=$(( aws_weight * 100 / total_weight ))
        azure_weight=$(( azure_weight * 100 / total_weight ))
    fi

    # Update routing configuration
    update_cloudflare_weights "${aws_weight}" "${azure_weight}"

    # Save current state
    cat > "${CONFIG_FILE}" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "aws_endpoint": "${aws_endpoint}",
    "azure_endpoint": "${azure_endpoint}",
    "aws_healthy": ${aws_healthy},
    "azure_healthy": ${azure_healthy},
    "aws_response_time": "${aws_response_time}",
    "azure_response_time": "${azure_response_time}",
    "preferred_cloud": "${preferred_cloud}",
    "aws_weight": ${aws_weight},
    "azure_weight": ${azure_weight}
}
EOF

    log "Traffic routing update completed successfully"
    log "Final weights: AWS=${aws_weight}%, Azure=${azure_weight}%"
}

# Error handling
trap 'log "Script failed at line $LINENO"' ERR

# Run main function
main "$@"