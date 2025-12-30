# Troubleshooting Guide - Infrastructure Identity

## Overview

This document provides solutions to common issues encountered when working with the `infra-identity` repository.

For deployment procedures, see **[DEPLOYMENT.md](./DEPLOYMENT.md)**.
For architecture overview, see **[ARCHITECTURE.md](./ARCHITECTURE.md)**.

---

## Common Issues

### Problem: GitHub Actions authentication fails

**Symptoms:**

```
Error: AADSTS700016: Application with identifier '...' was not found in the directory
Error: AADSTS70021: No matching federated identity record found
```

**Causes:**

1. Service Principal not created or App ID incorrect
2. Federated Identity Credential (FIC) not configured
3. FIC subject claim doesn't match GitHub workflow
4. Wrong GitHub secrets

**Solution:**

**Step 1:** Verify Service Principal exists:

```bash
cd terraform/environments/dev
terraform output github_oidc_service_principal_app_id
```

Copy the output App ID.

**Step 2:** Check GitHub secrets match:

Repository → Settings → Secrets and variables → Actions

Verify `AZURE_CLIENT_ID` matches the output from Step 1.

**Step 3:** Verify Federated Identity Credential:

```bash
SP_APP_ID=$(terraform output -raw github_oidc_service_principal_app_id)
az ad app federated-credential list --id $SP_APP_ID --output table
```

**Step 4:** Check subject claim matches workflow:

For service repos (branch-based):

- **Expected subject:** `repo:hycom/billing-service:ref:refs/heads/main`
- **Workflow trigger:** Push to `main` branch

For GitOps repos (environment-based):

- **Expected subject:** `repo:hycom/gitops:environment:dev`
- **Workflow trigger:** Deployment to `dev` environment

**Step 5:** Verify GitHub workflow has correct permissions:

```yaml
permissions:
  id-token: write  # ← Required for OIDC
  contents: read
```

---

### Problem: Pod cannot access Azure Key Vault

**Symptoms:**

```
Error: Caller is not authorized to perform action on resource
Error: Failed to get secret from Key Vault
```

**Causes:**

1. Workload Identity not configured correctly
2. Kubernetes Service Account not annotated
3. Pod not using correct Service Account
4. RBAC role not assigned
5. Workload Identity not enabled on AKS cluster

**Solution:**

**Step 1:** Verify Workload Identity is enabled on AKS:

```bash
az aks show \
  --resource-group rg-ecare-dev \
  --name aks-ecare-dev \
  --query "oidcIssuerProfile.enabled" -o tsv
```

Expected: `true`

**Step 2:** Verify Managed Identity exists:

```bash
az identity show \
  --resource-group rg-ecare-dev \
  --name mi-ecare-billing-dev
```

**Step 3:** Verify Kubernetes Service Account annotation:

```bash
kubectl describe sa sa-billing -n ecare
```

Expected annotation:

```yaml
Annotations:  azure.workload.identity/client-id: <UAMI-client-id>
```

If missing, check Terraform:

```bash
cd terraform/environments/dev
terraform output workload_identities
```

**Step 4:** Verify pod uses correct Service Account:

```bash
kubectl get pod <pod-name> -n ecare -o yaml | grep serviceAccountName
```

Expected: `serviceAccountName: sa-billing`

**Step 5:** Verify pod has correct label:

```bash
kubectl get pod <pod-name> -n ecare -o yaml | grep -A 2 labels
```

Expected label:

```yaml
labels:
  azure.workload.identity/use: "true"
```

**Step 6:** Verify RBAC role assignment:

```bash
IDENTITY_PRINCIPAL_ID=$(az identity show \
  --resource-group rg-ecare-dev \
  --name mi-ecare-billing-dev \
  --query principalId -o tsv)

az role assignment list \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --output table
```

Expected role: `Key Vault Secrets User` on Key Vault resource.

**Step 7:** If role missing, check Terraform configuration:

```hcl
# terraform.tfvars
services = {
  billing = {
    # ...
    enable_key_vault_access = true  # ← Must be true
  }
}
```

---

### Problem: Terraform remote state not found

**Symptoms:**

```
Error: No outputs found in the remote state
Error: Failed to get outputs from remote state: infra-platform
```

**Causes:**

1. `infra-platform` not deployed yet
2. Wrong remote state backend configuration
3. Authentication issues

**Solution:**

**Step 1:** Verify `infra-platform` is deployed:

```bash
cd /path/to/infra-platform/terraform/environments/dev
terraform output
```

If no outputs, deploy `infra-platform` first.

**Step 2:** Verify backend configuration in `infra-identity`:

```hcl
# terraform/environments/dev/versions.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-ecare-dev"
    storage_account_name = "tfstatefmsecaredev"
    container_name       = "tfstate"
    key                  = "infra-identity/terraform.tfstate"  # ← Correct path
  }
}
```

**Step 3:** Check remote state data source:

```hcl
# terraform/environments/dev/main.tf
data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-ecare-dev"
    storage_account_name = "tfstatefmsecaredev"
    container_name       = "tfstate"
    key                  = "infra-platform/terraform.tfstate"  # ← Correct
  }
}
```

**Step 4:** Verify authentication to storage account:

```bash
az storage account show \
  --name tfstatefmsecaredev \
  --resource-group rg-ecare-dev
```

---

### Problem: Kubernetes provider initialization fails

**Symptoms:**

```
Error: Kubernetes cluster unreachable
Error: Unable to connect to the server
```

**Causes:**

1. AKS cluster not deployed
2. Wrong AKS cluster name
3. Authentication issues
4. Network connectivity

**Solution:**

**Step 1:** Verify AKS cluster exists:

```bash
az aks show \
  --resource-group rg-ecare-dev \
  --name aks-ecare-dev
```

**Step 2:** Get AKS credentials:

```bash
az aks get-credentials \
  --resource-group rg-ecare-dev \
  --name aks-ecare-dev \
  --overwrite-existing
```

**Step 3:** Test kubectl connectivity:

```bash
kubectl get nodes
kubectl get namespaces
```

**Step 4:** Verify Kubernetes provider configuration:

```hcl
# terraform/environments/dev/kubernetes-provider.tf
provider "kubernetes" {
  host                   = data.terraform_remote_state.platform.outputs.aks_host
  cluster_ca_certificate = base64decode(data.terraform_remote_state.platform.outputs.aks_cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login", "azurecli",
      "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"  # ← Azure Kubernetes Service AAD Server
    ]
  }
}
```

**Step 5:** Install kubelogin (if missing):

```bash
# macOS
brew install Azure/kubelogin/kubelogin

# Verify
kubelogin --version
```

---

### Problem: `terraform apply` fails due to existing Kubernetes Service Account

**Symptoms:**

```
Error: Service Account "sa-billing" already exists
```

**Causes:**

1. Service Account created manually
2. Previous Terraform apply partially completed
3. Terraform state out of sync

**Solution:**

**Option A:** Import existing Service Account:

```bash
terraform import 'module.environment.module.workload_identity["billing"].kubernetes_service_account.workload' ecare/sa-billing
```

**Option B:** Delete existing Service Account and let Terraform recreate:

```bash
kubectl delete sa sa-billing -n ecare
terraform apply
```

**Option C:** Check Terraform state:

```bash
terraform state list | grep kubernetes_service_account
terraform state show 'module.environment.module.workload_identity["billing"].kubernetes_service_account.workload'
```

---

### Problem: RBAC role assignment fails

**Symptoms:**

```
Error: Authorization failed for template resource
Error: The client does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'
```

**Causes:**

1. Insufficient permissions (need `User Access Administrator` or `Owner`)
2. Service Principal doesn't have permission to assign roles
3. Trying to assign role at wrong scope

**Solution:**

**Step 1:** Verify your permissions:

```bash
az role assignment list \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --output table
```

Required: `User Access Administrator` or `Owner` on subscription or resource group.

**Step 2:** If deploying via GitHub Actions, verify Service Principal permissions:

```bash
# Get Terraform Service Principal (from infra-foundation)
SP_APP_ID="<app-id-from-foundation>"

az role assignment list \
  --assignee $SP_APP_ID \
  --output table
```

Required: `User Access Administrator` role.

**Step 3:** Add missing role assignment:

```bash
# If deploying manually
az role assignment create \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-ecare-dev"

# If deploying via GitHub Actions
az role assignment create \
  --assignee $SP_APP_ID \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-ecare-dev"
```

---

### Problem: Service name conflicts

**Symptoms:**

```
Error: Duplicate service name in configuration
Error: Resource already exists with name "mi-ecare-billing-dev"
```

**Causes:**

1. Service name used multiple times in `terraform.tfvars`
2. Service name conflicts with existing Managed Identity
3. Naming convention inconsistency

**Solution:**

**Step 1:** Check for duplicate service names:

```bash
grep -n "billing" terraform/environments/dev/terraform.tfvars
```

**Step 2:** Verify naming convention:

Service names must be:

- Unique per environment
- Lowercase, alphanumeric, hyphens only
- Match between `service_repos` and `services`

**Correct:**

```hcl
service_repos = {
  billing = { ... }
}

services = {
  billing = { ... }
}
```

**Incorrect:**

```hcl
service_repos = {
  billing = { ... }
}

services = {
  billing-service = { ... }  # ← Mismatch!
}
```

**Step 3:** If Managed Identity already exists, import or rename:

```bash
# Option A: Import
terraform import 'module.environment.module.workload_identity["billing"].azurerm_user_assigned_identity.workload' \
  /subscriptions/<sub-id>/resourceGroups/rg-ecare-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-ecare-billing-dev

# Option B: Rename service
# Change service name in terraform.tfvars to "billing-v2" or similar
```

---

### Problem: Namespace not found

**Symptoms:**

```
Error: namespaces "ecare" not found
```

**Causes:**

1. Kubernetes namespace not created
2. Wrong namespace name in configuration

**Solution:**

**Step 1:** Check if namespace exists:

```bash
kubectl get namespace ecare
```

**Step 2:** Create namespace if missing:

```bash
kubectl create namespace ecare
```

**Step 3:** Verify Terraform configuration:

```hcl
# terraform.tfvars
services = {
  billing = {
    # ...
    namespace = "ecare"  # ← Must match existing namespace
  }
}
```

**Note:** This Terraform configuration does **not** create the namespace. Namespace must be created by:

- `infra-platform` (if it creates namespaces)
- Manual `kubectl create namespace ecare`
- GitOps repository (ArgoCD, Flux)

---

### Problem: Federated Identity Credential subject claim error

**Symptoms:**

```
Error: AADSTS70021: No matching federated identity record found for presented assertion
```

**Causes:**

1. GitHub workflow subject doesn't match FIC configuration
2. Wrong branch name in `terraform.tfvars`
3. Wrong repository name
4. Wrong environment name (for GitOps repos)

**Solution:**

**Step 1:** Get expected subject claim:

```bash
SP_APP_ID=$(terraform output -raw github_oidc_service_principal_app_id)
az ad app federated-credential list --id $SP_APP_ID --query "[].subject" -o tsv
```

**Step 2:** Compare with GitHub workflow context:

For service repos (branch-based):

- **Expected:** `repo:hycom/billing-service:ref:refs/heads/main`
- **GitHub context:** Workflow triggered by push to `main` branch

For GitOps repos (environment-based):

- **Expected:** `repo:hycom/gitops:environment:dev`
- **GitHub context:** Workflow uses environment `dev`

**Step 3:** Verify Terraform configuration matches GitHub:

```hcl
# terraform.tfvars
service_repos = {
  billing = {
    repo   = "hycom/billing-service"  # ← Must match GitHub repo
    branch = "main"                    # ← Must match GitHub branch
  }
}
```

**Step 4:** Update Terraform if mismatch:

```bash
terraform apply  # Recreates FIC with correct subject
```

---

### Problem: Pre-commit hooks fail

**Symptoms:**

```
terraform_validate...Failed
conventional-commit..Failed
```

**Causes:**

1. Terraform modules not initialized
2. Commit message doesn't follow Conventional Commits format
3. Missing pre-commit dependencies

**Solution:**

**For terraform_validate:**

```bash
# Initialize Terraform first
cd terraform/environments/dev
terraform init
cd ../../..

# Retry commit
git commit -m "message"
```

**For conventional-commit:**

Use correct commit message format:

```bash
# Correct format: type(scope): description
git commit -m "feat(identity): add notification service"
git commit -m "fix(workload): correct RBAC role assignment"
git commit -m "docs(readme): update deployment instructions"

# Valid types: feat, fix, docs, style, refactor, test, chore
```

---

## Getting Help

### Check Documentation

1. **[DEPLOYMENT.md](./DEPLOYMENT.md)**: Deployment procedures
2. **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Architecture overview
3. **[NAMING-CONVENTIONS.md](./NAMING-CONVENTIONS.md)**: Naming patterns
4. **Module READMEs**: `terraform/modules/*/README.md`

### Verification Commands

```bash
# Verify Service Principal
az ad sp list --display-name "sp-gha-ecare-dev" --output table

# Verify Managed Identities
az identity list --resource-group rg-ecare-dev --output table

# Verify Kubernetes Service Accounts
kubectl get sa -n ecare

# Verify RBAC role assignments
az role assignment list --assignee <principal-id> --output table
```

### Azure Portal Checks

1. Navigate to Azure Portal → Azure Active Directory → App registrations
2. Find `sp-gha-ecare-dev`
3. Check Certificates & secrets → Federated credentials
4. Check Owners & permissions

### Test Authentication

**GitHub Actions:**

Create test workflow (see [DEPLOYMENT.md - Test GitHub Actions Authentication](./DEPLOYMENT.md#test-github-actions-authentication))

**Workload Identity:**

Deploy test pod (see [DEPLOYMENT.md - Test Workload Identity from Pod](./DEPLOYMENT.md#test-workload-identity-from-pod))

### Support Channels

- **Internal Documentation**: `docs/` directory
- **Azure Documentation**: [docs.microsoft.com/azure](https://docs.microsoft.com/en-us/azure/)
- **Terraform Documentation**: [terraform.io](https://www.terraform.io/docs)
- **AKS Workload Identity**: [Azure Workload Identity docs](https://azure.github.io/azure-workload-identity/)
- **Team**: Contact DevOps team for assistance
