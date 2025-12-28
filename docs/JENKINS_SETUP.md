# Jenkins Setup for Multi-Cloud Pipeline

## Prerequisites

1. Jenkins server with Docker support
2. Required plugins installed (see `jenkins-plugins.txt`)
3. Cloud provider CLI tools installed on Jenkins agents
4. Credentials configured in Jenkins

## Credentials Configuration

Configure the following credentials in Jenkins (`Manage Jenkins > Credentials`):

### AWS Credentials
- **Type**: AWS Credentials
- **ID**: `aws-credentials`
- **Access Key ID**: Your AWS Access Key ID
- **Secret Access Key**: Your AWS Secret Access Key

### Azure Service Principal
- **Type**: Username with password
- **ID**: `azure-service-principal`
- **Username**: Azure Client ID
- **Password**: Azure Client Secret

### Azure Additional Credentials
- **Type**: Secret text
- **ID**: `azure-tenant-id`
- **Secret**: Your Azure Tenant ID

- **Type**: Secret text
- **ID**: `azure-subscription-id`
- **Secret**: Your Azure Subscription ID

- **Type**: Secret text
- **ID**: `azure-container-registry`
- **Secret**: Your Azure Container Registry name

## Pipeline Configuration

1. Create a new Pipeline job in Jenkins
2. Set the pipeline definition to "Pipeline script from SCM"
3. Configure the repository URL and credentials
4. Set the script path to `jenkins/Jenkinsfile`

## Environment Variables

Set these environment variables in your Jenkins pipeline or globally:

```bash
# Docker Registry Configuration
DOCKER_REGISTRY=your-registry-url
DOCKER_REPOSITORY=multi-cloud-app

# AWS Configuration
AWS_REGION=us-west-2
AWS_ECS_CLUSTER=prod-cluster
AWS_ECS_SERVICE=prod-web-app-service

# Azure Configuration
AZURE_RESOURCE_GROUP=prod-multi-cloud-app-rg
```

## Required Tools on Jenkins Agents

Ensure the following tools are installed on your Jenkins build agents:

- Docker
- AWS CLI v2
- Azure CLI
- Node.js (for application testing)
- jq (for JSON processing)
- curl (for health checks)
- Terraform (if using infrastructure updates)

## Pipeline Stages

The pipeline includes the following stages:

1. **Checkout**: Get source code and generate build tags
2. **Build Application**: Build Docker image
3. **Test Application**: Run tests and validate Docker image
4. **Push to Registries**: Push to both AWS ECR and Azure ACR
5. **Deploy to Clouds**: Deploy to AWS ECS and Azure ACI in parallel
6. **Health Check & Validation**: Verify deployments are healthy
7. **Update Traffic Routing**: Update DNS routing based on health

## Slack Notifications

Configure Slack notifications by:

1. Install the Slack plugin
2. Configure Slack in `Manage Jenkins > Configure System`
3. Add your Slack workspace and channel configuration
4. The pipeline will automatically send notifications on success/failure

## Troubleshooting

### Common Issues

1. **Docker build fails**: Ensure Docker daemon is running on Jenkins agent
2. **AWS deployment fails**: Check AWS credentials and permissions
3. **Azure deployment fails**: Verify Azure service principal has sufficient permissions
4. **Health checks fail**: Ensure applications are properly configured with health endpoints

### Required Permissions

#### AWS IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*",
                "ecs:*",
                "logs:*"
            ],
            "Resource": "*"
        }
    ]
}
```

#### Azure Service Principal Permissions
- Contributor role on the resource group
- AcrPush role on the container registry

## Security Best Practices

1. Use least privilege access for service accounts
2. Rotate credentials regularly
3. Store sensitive data in Jenkins credentials store
4. Use separate credentials for different environments
5. Audit access and deployment logs regularly