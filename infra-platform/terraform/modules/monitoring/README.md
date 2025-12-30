# Monitoring Module

Terraform module for deploying Azure monitoring infrastructure including Log Analytics Workspace and
Application Insights.

## Resources Created

- **Log Analytics Workspace** - Central logging and monitoring workspace
- **Application Insights** - Application performance monitoring

## Features

- Centralized logging and monitoring
- Application Insights integrated with Log Analytics
- Configurable retention period (30-730 days)
- Support for multiple application types
- Automatic tagging

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  project_name        = "ecare"

  log_analytics_sku            = "PerGB2018"
  log_analytics_retention_days = 30
  application_insights_type    = "web"

  tags = {
    Environment = "dev"
    Project     = "ecare"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Name of the resource group | `string` | - | yes |
| location | Azure region for resources | `string` | - | yes |
| environment | Environment name (dev, test, stage, prod) | `string` | - | yes |
| project_name | Project name for resource naming | `string` | `"ecare"` | no |
| log_analytics_sku | SKU for Log Analytics Workspace | `string` | `"PerGB2018"` | no |
| log_analytics_retention_days | Retention period in days for Log Analytics | `number` | `30` | no |
| application_insights_type | Application type for Application Insights | `string` | `"web"` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| log_analytics_workspace_id | ID of the Log Analytics Workspace | no |
| log_analytics_workspace_name | Name of the Log Analytics Workspace | no |
| log_analytics_workspace_workspace_id | Workspace ID (GUID) of the Log Analytics Workspace | no |
| log_analytics_primary_shared_key | Primary shared key for Log Analytics Workspace | yes |
| application_insights_id | ID of the Application Insights instance | no |
| application_insights_name | Name of the Application Insights instance | no |
| application_insights_instrumentation_key | Instrumentation Key for Application Insights | yes |
| application_insights_connection_string | Connection String for Application Insights | yes |
| application_insights_app_id | Application ID of the Application Insights instance | no |

## Module-Specific Configuration

### Integration with AKS Module

Log Analytics Workspace is used by AKS for Container Insights:

```hcl
module "aks" {
  source = "../../modules/aks"
  
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable_container_insights  = true
  
  # ... other variables
}
```

### Application Services

Application Insights connection string can be used by applications for telemetry:

```bash
# Connection string output
export APPLICATIONINSIGHTS_CONNECTION_STRING=$(terraform output -raw application_insights_connection_string)
```

## Naming Convention

Resources follow this naming pattern:

- Log Analytics Workspace: `log-{project_name}-{environment}`
- Application Insights: `appi-{project_name}-{environment}`

## Security Features

- **Centralized Logging**: All logs stored in Log Analytics Workspace
- **Data Retention**: Configurable retention period (30-730 days)
- **Cost Optimization**: Pay-As-You-Go pricing (PerGB2018 SKU)
- **Application Insights**: Integrated with Log Analytics Workspace

## Examples

### Development Environment

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = "rg-ecare-dev"
  location            = "West Europe"
  environment         = "dev"
  
  log_analytics_retention_days = 30
}
```

### Production Environment

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = "rg-ecare-prod"
  location            = "West Europe"
  environment         = "prod"
  
  log_analytics_retention_days = 90  # Longer retention for production
}
```

## Integration with Other Modules

No specific integration with other modules.

## Prerequisites

From Phase 1 (infra-foundation):

- No specific prerequisites required (monitoring is typically deployed early in the infrastructure setup)

## Terraform Version

- Terraform >= 1.5.0
- AzureRM Provider ~> 3.0
