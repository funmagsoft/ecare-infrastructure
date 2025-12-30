# Infrastructure Platform - Architecture

## Overview

The `infra-platform` component provides the platform infrastructure layer for the ecare project. It creates all application-level infrastructure including Kubernetes clusters, databases, storage, and monitoring.

## Purpose

This component serves as **Phase 3** of the infrastructure setup and creates:

1. **Compute Infrastructure**: AKS clusters with Workload Identity and OIDC enabled
2. **Data Infrastructure**: PostgreSQL Flexible Server, Storage Accounts
3. **Security Infrastructure**: Key Vault for secrets management
4. **Messaging Infrastructure**: Service Bus for async communication
5. **Container Infrastructure**: Azure Container Registry (ACR)
6. **Management Infrastructure**: Bastion VM for secure access
7. **Monitoring Infrastructure**: Log Analytics and Application Insights

## Infrastructure Layers

### Prerequisites (Phase 1 & 2)

Before deploying platform infrastructure, the following must exist:

**From Phase 1 (infra-foundation):**
- Virtual Network with subnets (AKS, Data, Management)
- Network Security Groups
- Remote state storage

**From Phase 2 (infra-identity):**
- Service Principals for GitHub Actions OIDC
- Workload Identities for application services

### Platform Components

#### 1. AKS Cluster

- **System Node Pool**: Critical system pods (CoreDNS, metrics-server)
- **User Node Pool**: Application workloads (auto-scaling enabled)
- **Network**: Azure CNI with Azure Network Policy
- **Identity**: Workload Identity enabled for pod-to-Azure authentication
- **OIDC**: Issuer URL exported for Federated Identity Credentials

#### 2. PostgreSQL Flexible Server

- **High Availability**: Zone-redundant (production)
- **Backup**: Automated backups with configurable retention
- **Network**: Private Endpoint (no public access)
- **Security**: SSL/TLS enforced, admin credentials in Key Vault

#### 3. Storage Accounts

- **Containers**: app-data, logs, backups
- **Features**: Versioning, soft delete, encryption at rest
- **Network**: Private Endpoint (no public access)
- **Access**: Managed Identity-based authentication

#### 4. Key Vault

- **Purpose**: Centralized secrets management
- **Features**: Soft delete, purge protection (production)
- **Network**: Private Endpoint (no public access)
- **Access**: RBAC-based authorization

#### 5. Service Bus

- **SKU**: Standard (dev/test), Premium (production)
- **Features**: Zone redundancy (production)
- **Network**: Private Endpoint when supported by SKU

#### 6. Azure Container Registry (ACR)

- **SKU**: Premium (Private Endpoint support)
- **Features**: Geo-replication, retention policies
- **Network**: Private Endpoint (no public access)
- **Access**: Managed Identity for AKS pull

#### 7. Bastion VM

- **Purpose**: Secure jump host for database/cluster access
- **Tools**: kubectl, psql, az cli, docker, helm
- **Access**: SSH with public key authentication
- **Network**: Public IP for SSH, private access to resources

#### 8. Monitoring

- **Log Analytics**: Centralized logging for all resources
- **Application Insights**: Application performance monitoring
- **Integration**: AKS Container Insights enabled

## Module Architecture

### Environment Module

The `environment` module encapsulates all platform infrastructure for a single environment:

```
modules/environment/
├── data.tf              # Remote state, resource group lookups
├── locals.tf            # Common tags, subnet IDs from foundation
├── monitoring.tf        # Log Analytics + Application Insights
├── storage.tf           # Storage Account + PostgreSQL
├── security.tf          # Key Vault
├── messaging.tf         # Service Bus
├── container-registry.tf # ACR
├── compute.tf           # AKS + Bastion
├── variables.tf         # Input variables
├── outputs.tf           # Exported values
└── versions.tf          # Provider requirements
```

### Individual Modules

Each service has its own reusable module:

- `aks/`: Kubernetes cluster with node pools
- `acr/`: Container registry with private endpoint
- `bastion/`: Jump host VM with tools
- `key-vault/`: Secrets management
- `monitoring/`: Observability stack
- `postgresql/`: Database server
- `service-bus/`: Message broker
- `storage/`: Blob storage

## Network Architecture

### Private Endpoints

All data services use Private Endpoints for secure, private connectivity:

```
AKS Subnet (10.1.1.0/24)
  └─> AKS Cluster

Data Subnet (10.1.2.0/24)
  ├─> PostgreSQL Private Endpoint
  ├─> Storage Private Endpoint
  ├─> Key Vault Private Endpoint
  ├─> ACR Private Endpoint
  └─> Service Bus Private Endpoint (Premium)

Management Subnet (10.1.3.0/24)
  └─> Bastion VM
```

### DNS Resolution

Private DNS Zones for each service:

- `privatelink.postgres.database.azure.com`
- `privatelink.blob.core.windows.net`
- `privatelink.vaultcore.azure.net`
- `privatelink.azurecr.io`
- `privatelink.servicebus.windows.net`

## Security Architecture

### Identity & Access

- **AKS Pods**: Workload Identity (Managed Identity + FIC)
- **GitHub Actions**: Service Principal + OIDC FIC
- **Bastion Access**: SSH key-based authentication
- **Key Vault**: RBAC-based authorization

### Network Security

- **Public Access**: Disabled for all data services
- **Private Endpoints**: All traffic over Azure backbone
- **NSG Rules**: Restrictive rules on all subnets
- **Bastion**: Only entry point with public IP

### Data Protection

- **Encryption at Rest**: All storage and databases
- **Encryption in Transit**: TLS 1.2+ enforced
- **Backup**: Automated with retention policies
- **Soft Delete**: Enabled for accidental deletion protection

## Deployment Flow

1. **Prerequisites Validation**: Check foundation and identity phases
2. **Monitoring**: Deploy Log Analytics and Application Insights first
3. **Storage**: Deploy Storage Account and PostgreSQL
4. **Security**: Deploy Key Vault and store credentials
5. **Messaging**: Deploy Service Bus
6. **Container Registry**: Deploy ACR
7. **Compute**: Deploy AKS cluster and Bastion VM
8. **Namespace**: Create shared Kubernetes namespace

## Tagging Strategy

All resources are tagged with:

- `Environment`: dev, test, stage, prod
- `Project`: ecare
- `ManagedBy`: Terraform
- `Phase`: Platform
- `GitRepository`: infra-platform
- `TerraformPath`: terraform/environments/{env}
- `DeploymentId`: Unique 8-char identifier for cleanup
- `Module`: Specific module name (aks, storage, etc.)

## State Management

Each environment maintains separate Terraform state:

- **Backend**: Azure Storage Account (created in Phase 0)
- **State File**: `infra-platform/terraform.tfstate`
- **Locking**: Azure Blob lease-based locking
- **Authentication**: Azure AD (use_azuread_auth = true)

## Dependencies

### Phase 1 (infra-foundation) Outputs

- `vnet_id`: Virtual Network ID
- `aks_subnet_id`: Subnet for AKS nodes
- `data_subnet_id`: Subnet for Private Endpoints
- `mgmt_subnet_id`: Subnet for Bastion VM
- `vnet_name`: VNet name for DNS zone links

### Phase 2 (infra-identity) Outputs

- `aks_oidc_issuer_url`: For Workload Identity FIC
- `service_principal_client_id`: For GitHub Actions
- `workload_identities`: Managed Identities for services

## Terraform Version

- **Terraform**: >= 1.5.0
- **AzureRM Provider**: ~> 3.80
- **Kubernetes Provider**: ~> 2.0

