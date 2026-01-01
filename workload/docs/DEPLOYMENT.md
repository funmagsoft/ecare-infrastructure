# Deployment Guide - Infrastructure Identity

## Overview

This document provides step-by-step procedures for deploying and managing the `workload` repository.

For architecture overview, see **[ARCHITECTURE.md](./ARCHITECTURE.md)**.
For troubleshooting, see **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deployment Procedures](#deployment-procedures)
   - [Procedure 1: First-Time Deployment](#procedure-1-first-time-deployment)
   - [Procedure 2: Adding a New Service](#procedure-2-adding-a-new-service)
   - [Procedure 3: Updating Service Configuration](#procedure-3-updating-service-configuration)
   - [Procedure 4: Deploying to Additional Environment](#procedure-4-deploying-to-additional-environment)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Cleanup](#cleanup)
7. [CI/CD Integration](#cicd-integration)

---

## Prerequisites

### Infrastructure Prerequisites

Before deploying `workload`, ensure the following are deployed:

1. **foundation** (Phase 1):
   - ✓ Resource Groups (`rg-ecare-{env}`)
   - ✓ Virtual Network and subnets
   - ✓ Terraform state Storage Account (`tfstatefmsecaredev`)

2. **platform** (Phase 2):
   - ✓ Azure Container Registry (ACR)
   - ✓ Azure Kubernetes Service (AKS) cluster
     - Workload Identity enabled
     - OIDC issuer enabled
   - ✓ Key Vault (if services need access)
   - ✓ Storage Account (if services need access)
   - ✓ Service Bus Namespace (if services need access)

**Verification:**

```bash
# Check if foundation and platform are deployed
cd /path/to/foundation/terraform/environments/dev
terraform output

cd /path/to/platform/terraform/environments/dev
terraform output
```

### Local Prerequisites

1. **Azure CLI**: >= 2.50.0
2. **Terraform**: >= 1.5.0
3. **kubectl**: >= 1.24 (for Kubernetes resource verification)
4. **Git**: For version control
5. **jq**: For JSON processing (optional, for scripts)

**Install:**

```bash
# macOS
brew install azure-cli terraform kubectl jq

# Verify versions
az version
terraform version
kubectl version --client
```

### Azure Authentication

```bash
# Login to Azure
az login

# Select subscription
az account set --subscription "Your Subscription Name"

# Verify
az account show
```

---

## Initial Setup

### Step 1: Clone Repository

```bash
cd /path/to/ecare-infrastructure
cd workload
```

### Step 2: Review Configuration

Check `terraform/environments/dev/terraform.tfvars.example` for configuration examples.

### Step 3: Create Configuration File

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values (see [Configuration](#configuration) section).

### Step 4: Initialize Terraform

```bash
terraform init
```

**Expected output:**

```
Initializing the backend...
Successfully configured the backend "azurerm"!

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.0"...
- Finding hashicorp/azuread versions matching "~> 2.0"...
- Finding hashicorp/kubernetes versions matching "~> 2.0"...

Terraform has been successfully initialized!
```

---

## Deployment Procedures

### Procedure 1: First-Time Deployment

**Scenario:** First deployment of identity infrastructure to an environment.

**Steps:**

#### 1. Configure Services

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
environment  = "dev"
project_name = "ecare"
organization_name = "hycom"

# GitHub OIDC: Service Repositories
service_repos = {
  billing = {
    repo   = "hycom/billing-service"
    branch = "main"
  }
  inventory = {
    repo   = "hycom/inventory-service"
    branch = "main"
  }
}

# GitHub OIDC: GitOps Repositories
gitops_repos = ["hycom/gitops"]

# Workload Identities: Services Configuration
services = {
  billing = {
    repo                      = "hycom/billing-service"
    branch                    = "main"
    enable_key_vault_access   = true
    enable_storage_access     = true
    enable_service_bus_access = true
    namespace                 = "ecare"
  }
  inventory = {
    repo                      = "hycom/inventory-service"
    branch                    = "main"
    enable_key_vault_access   = true
    enable_service_bus_access = false
    namespace                 = "ecare"
  }
}

# Optional: Additional tags
tags = {
  CostCenter = "Engineering"
  Team       = "DevOps"
}
```

#### 2. Plan Deployment

```bash
cd terraform/environments/dev
terraform plan
```

**Review the plan carefully:**

- ✓ Service Principal `sp-gha-ecare-dev` will be created
- ✓ Federated Identity Credentials for GitHub repos
- ✓ User Assigned Managed Identities per service (`mi-ecare-billing-dev`, etc.)
- ✓ Kubernetes Service Accounts per service
- ✓ RBAC role assignments

#### 3. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment time:** ~5-10 minutes

#### 4. Capture Outputs

```bash
# Service Principal App ID (needed for GitHub Actions secrets)
terraform output github_oidc_service_principal_app_id

# All workload identities
terraform output workload_identities
```

**Save outputs** for GitHub Actions configuration.

#### 5. Configure GitHub Actions Secrets

For each service repository (e.g., `billing-service`):

Navigate to GitHub → Repository → Settings → Secrets and variables → Actions

Add secrets:

- `AZURE_CLIENT_ID`: Output from `github_oidc_service_principal_app_id`
- `AZURE_TENANT_ID`: Your Azure tenant ID (from `az account show`)
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

#### 6. Verify Deployment

See [Verification](#verification) section.

---

### Procedure 2: Adding a New Service

**Scenario:** Add a new service (e.g., `notification-service`) to existing environment.

**Steps:**

#### 1. Update Configuration

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
service_repos = {
  # ... existing services ...
  notification = {
    repo   = "hycom/notification-service"
    branch = "main"
  }
}

services = {
  # ... existing services ...
  notification = {
    repo                      = "hycom/notification-service"
    branch                    = "main"
    enable_key_vault_access   = true
    enable_service_bus_access = true
    namespace                 = "ecare"
  }
}
```

#### 2. Plan and Apply

```bash
cd terraform/environments/dev
terraform plan   # Review: Only notification service resources added
terraform apply
```

#### 3. Configure GitHub Actions Secrets

Add secrets to `notification-service` repository (same as Procedure 1, Step 5).

#### 4. Verify

```bash
# Check new Managed Identity
az identity show \
  --resource-group rg-ecare-dev \
  --name mi-ecare-notification-dev

# Check Kubernetes Service Account
kubectl get sa sa-notification -n ecare
```

---

### Procedure 3: Updating Service Configuration

**Scenario:** Change service permissions (e.g., enable Storage access for existing service).

**Steps:**

#### 1. Update Configuration

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
services = {
  inventory = {
    repo                      = "hycom/inventory-service"
    branch                    = "main"
    enable_key_vault_access   = true
    enable_storage_access     = true  # ← Changed from false
    enable_service_bus_access = false
    namespace                 = "ecare"
  }
}
```

#### 2. Plan and Apply

```bash
terraform plan   # Review: New RBAC role assignment for Storage
terraform apply
```

#### 3. Verify RBAC

```bash
# Check role assignments for service identity
IDENTITY_PRINCIPAL_ID=$(az identity show \
  --resource-group rg-ecare-dev \
  --name mi-ecare-inventory-dev \
  --query principalId -o tsv)

az role assignment list \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --output table
```

Expected: New role `Storage Blob Data Contributor`

---

### Procedure 4: Deploying to Additional Environment

**Scenario:** Deploy identity infrastructure to `test` environment.

**Steps:**

#### 1. Create Configuration

```bash
cd terraform/environments/test
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with test-specific values:

```hcl
environment  = "test"
project_name = "ecare"
# ... same service configuration as dev ...
```

#### 2. Initialize Terraform

```bash
terraform init
```

#### 3. Plan and Apply

```bash
terraform plan
terraform apply
```

#### 4. Configure GitHub Actions Secrets

Add environment-specific secrets in GitHub:

Repository → Settings → Environments → `test`

Add secrets (same as dev, but from test outputs).

#### 5. Verify

```bash
# Check Service Principal
az ad sp list --display-name "sp-gha-ecare-test" --query "[].appId" -o tsv

# Check Managed Identities
az identity list --resource-group rg-ecare-test --output table
```

---

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `environment` | Environment name | `"dev"`, `"test"`, `"stage"`, `"prod"` |
| `project_name` | Project name | `"ecare"` |
| `organization_name` | GitHub organization | `"hycom"` |
| `service_repos` | GitHub service repos (CI/CD) | See below |
| `services` | Service workload identities | See below |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `gitops_repos` | GitOps repository names | `[]` |
| `namespace` | Kubernetes namespace | `"ecare"` |
| `tags` | Additional resource tags | `{}` |

### Service Repos Configuration

```hcl
service_repos = {
  <service_name> = {
    repo   = "<org>/<repo-name>"  # GitHub repository
    branch = "<branch>"            # Default branch for CI/CD
  }
}
```

**Example:**

```hcl
service_repos = {
  billing = {
    repo   = "hycom/billing-service"
    branch = "main"
  }
}
```

### Services Configuration

```hcl
services = {
  <service_name> = {
    repo                      = "<org>/<repo-name>"
    branch                    = "<branch>"
    enable_key_vault_access   = <true|false>  # Key Vault Secrets User
    enable_storage_access     = <true|false>  # Storage Blob Data Contributor
    enable_service_bus_access = <true|false>  # Azure Service Bus Data Owner
    namespace                 = "<k8s-namespace>"  # Default: "ecare"

    # Optional: Custom RBAC roles
    additional_roles = [
      {
        role  = "<role-name>"
        scope = "<resource-id>"
      }
    ]
  }
}
```

**Example:**

```hcl
services = {
  billing = {
    repo                      = "hycom/billing-service"
    branch                    = "main"
    enable_key_vault_access   = true
    enable_storage_access     = true
    enable_service_bus_access = true
    namespace                 = "ecare"
    additional_roles = [
      {
        role  = "Contributor"
        scope = "/subscriptions/.../resourceGroups/rg-shared/providers/Microsoft.Storage/storageAccounts/sharedsa"
      }
    ]
  }
}
```

### Configuration Best Practices

1. **Start small**: Begin with minimal permissions, add as needed
2. **Match dev/prod**: Use same service configuration across environments
3. **Document custom roles**: Add comments for `additional_roles` explaining purpose
4. **Version control**: Commit `terraform.tfvars` (or use `.auto.tfvars` with secrets management)

---

## Verification

### Manual Verification

#### 1. Verify Service Principal

```bash
# Get Service Principal
az ad sp list --display-name "sp-gha-ecare-dev" --output table

# Check Federated Identity Credentials
SP_APP_ID=$(terraform output -raw github_oidc_service_principal_app_id)
az ad app federated-credential list --id $SP_APP_ID --output table
```

#### 2. Verify User Assigned Managed Identities

```bash
# List all identities
az identity list --resource-group rg-ecare-dev --output table

# Check specific identity
az identity show \
  --resource-group rg-ecare-dev \
  --name mi-ecare-billing-dev
```

#### 3. Verify Kubernetes Service Accounts

```bash
# List Service Accounts
kubectl get sa -n ecare

# Check annotation (should have azure.workload.identity/client-id)
kubectl describe sa sa-billing -n ecare
```

Expected annotation:

```yaml
Annotations:  azure.workload.identity/client-id: <UAMI-client-id>
```

#### 4. Verify RBAC Role Assignments

```bash
# For Service Principal (GitHub OIDC)
SP_OBJECT_ID=$(az ad sp list --display-name "sp-gha-ecare-dev" --query "[0].id" -o tsv)
az role assignment list --assignee $SP_OBJECT_ID --output table

# For Managed Identity (Workload)
IDENTITY_PRINCIPAL_ID=$(az identity show \
  --resource-group rg-ecare-dev \
  --name mi-ecare-billing-dev \
  --query principalId -o tsv)
az role assignment list --assignee $IDENTITY_PRINCIPAL_ID --output table
```

### Test GitHub Actions Authentication

Create a test workflow in service repository:

```yaml
name: Test Azure OIDC

on: workflow_dispatch

permissions:
  id-token: write
  contents: read

jobs:
  test-auth:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Test Azure CLI
        run: |
          az account show
          az acr list --output table
```

### Test Workload Identity from Pod

Deploy a test pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-workload-identity
  namespace: ecare
  labels:
    azure.workload.identity/use: "true"
spec:
  serviceAccountName: sa-billing
  containers:
  - name: azure-cli
    image: mcr.microsoft.com/azure-cli:latest
    command: ["sleep", "3600"]
```

Test access:

```bash
# Exec into pod
kubectl exec -it test-workload-identity -n ecare -- /bin/bash

# Test Azure authentication
az login --identity
az account show

# Test Key Vault access (if enabled)
az keyvault secret show --vault-name kv-ecare-dev --name test-secret
```

---

## Cleanup

### Procedure 1: Remove a Service

**Steps:**

#### 1. Update Configuration

Remove service from `terraform.tfvars`:

```hcl
service_repos = {
  # billing = { ... }  ← Commented out or removed
  inventory = { ... }
}

services = {
  # billing = { ... }  ← Commented out or removed
  inventory = { ... }
}
```

#### 2. Plan and Apply

```bash
terraform plan   # Review: Billing resources will be destroyed
terraform apply
```

### Procedure 2: Destroy All Resources

**⚠️ Warning:** This will destroy all identity infrastructure. Service authentication will stop working.

**Steps:**

#### 1. Terraform Destroy

```bash
cd terraform/environments/dev
terraform destroy
```

Type `yes` when prompted.

#### 2. Verify Cleanup

```bash
# Check no Service Principal
az ad sp list --display-name "sp-gha-ecare-dev"

# Check no Managed Identities
az identity list --resource-group rg-ecare-dev --output table

# Check no Kubernetes Service Accounts
kubectl get sa -n ecare
```

---

## CI/CD Integration

### GitHub Actions Workflow Example

**File:** `.github/workflows/deploy.yml` in service repository

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

env:
  ACR_NAME: acrecare${{ secrets.ENVIRONMENT }}
  IMAGE_NAME: billing-service
  AKS_CLUSTER: aks-ecare-${{ secrets.ENVIRONMENT }}
  RESOURCE_GROUP: rg-ecare-${{ secrets.ENVIRONMENT }}
  NAMESPACE: ecare

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Build and Push to ACR
        run: |
          az acr build \
            --registry $ACR_NAME \
            --image $IMAGE_NAME:${{ github.sha }} \
            --image $IMAGE_NAME:latest \
            --file Dockerfile .

      - name: Get AKS Credentials
        run: |
          az aks get-credentials \
            --resource-group $RESOURCE_GROUP \
            --name $AKS_CLUSTER \
            --overwrite-existing

      - name: Deploy to AKS
        run: |
          kubectl set image deployment/billing-service \
            billing-service=$ACR_NAME.azurecr.io/$IMAGE_NAME:${{ github.sha }} \
            -n $NAMESPACE
```

### Required GitHub Secrets

Set in GitHub repository settings:

- `AZURE_CLIENT_ID`: From `terraform output github_oidc_service_principal_app_id`
- `AZURE_TENANT_ID`: From `az account show --query tenantId -o tsv`
- `AZURE_SUBSCRIPTION_ID`: From `az account show --query id -o tsv`
- `ENVIRONMENT`: `dev`, `test`, `stage`, or `prod`

---

## Next Steps

1. **Deploy services**: Use GitHub Actions workflows to deploy service containers
2. **Monitor access**: Check Azure AD sign-in logs for authentication events
3. **Review RBAC**: Periodically audit role assignments (`az role assignment list`)
4. **Add environments**: Repeat for test, stage, prod

For issues, see **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**.
