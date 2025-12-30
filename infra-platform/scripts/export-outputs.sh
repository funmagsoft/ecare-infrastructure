#!/bin/bash
# Export Terraform outputs to JSON files for all environments

set -e

echo "=== Exporting Terraform Outputs ==="
echo ""

# Base directory for outputs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUTS_DIR="${REPO_DIR}/outputs"

# Create outputs directory if it doesn't exist
mkdir -p "$OUTPUTS_DIR"

# Environment to export (default: all)
ENVIRONMENTS="${1:-dev test stage prod}"

for ENV in $ENVIRONMENTS; do
  echo "Exporting outputs for ${ENV} environment..."

  ENV_DIR="${REPO_DIR}/terraform/environments/${ENV}"
  OUTPUT_FILE="${OUTPUTS_DIR}/terraform-outputs-${ENV}.json"

  if [ ! -d "$ENV_DIR" ]; then
    echo "  ✗ Environment directory not found: ${ENV_DIR}"
    continue
  fi

  # Navigate to environment directory
  cd "$ENV_DIR"

  # Check if Terraform is initialized
  if [ ! -d ".terraform" ]; then
    echo "  ⚠ Terraform not initialized for ${ENV}, initializing..."
    terraform init -input=false
  fi

  # Export outputs to JSON
  if terraform output -json > "$OUTPUT_FILE" 2>/dev/null; then
    echo "  ✓ Outputs exported to: ${OUTPUT_FILE}"

    # Show summary of outputs
    OUTPUT_COUNT=$(jq 'length' "$OUTPUT_FILE")
    echo "  ℹ Exported ${OUTPUT_COUNT} outputs"

    # Extract key outputs for display
    echo ""
    echo "  Key outputs for ${ENV}:"

    # AKS
    AKS_NAME=$(jq -r '.aks_cluster_name.value // "N/A"' "$OUTPUT_FILE")
    echo "    - AKS Cluster: ${AKS_NAME}"

    # PostgreSQL
    PSQL_FQDN=$(jq -r '.postgresql_fqdn.value // "N/A"' "$OUTPUT_FILE")
    echo "    - PostgreSQL FQDN: ${PSQL_FQDN}"

    # Key Vault
    KV_NAME=$(jq -r '.key_vault_name.value // "N/A"' "$OUTPUT_FILE")
    echo "    - Key Vault: ${KV_NAME}"

    # ACR
    ACR_SERVER=$(jq -r '.acr_login_server.value // "N/A"' "$OUTPUT_FILE")
    echo "    - ACR Login Server: ${ACR_SERVER}"

    # Storage
    STORAGE_NAME=$(jq -r '.storage_account_name.value // "N/A"' "$OUTPUT_FILE")
    echo "    - Storage Account: ${STORAGE_NAME}"

    # OIDC Issuer (important for Phase 3)
    OIDC_ISSUER=$(jq -r '.aks_oidc_issuer_url.value // "N/A"' "$OUTPUT_FILE")
    echo "    - AKS OIDC Issuer: ${OIDC_ISSUER}"

  else
    echo "  ✗ Failed to export outputs for ${ENV}"
    echo "  ℹ Make sure Terraform state exists and is accessible"
  fi

  echo ""
done

# Create combined outputs file
COMBINED_FILE="${OUTPUTS_DIR}/all-environments-outputs.json"
echo "Creating combined outputs file..."

cat > "$COMBINED_FILE" <<EOF
{
EOF

FIRST=true
for ENV in dev test stage prod; do
  OUTPUT_FILE="${OUTPUTS_DIR}/terraform-outputs-${ENV}.json"

  if [ -f "$OUTPUT_FILE" ]; then
    if [ "$FIRST" = false ]; then
      echo "," >> "$COMBINED_FILE"
    fi
    echo "  \"${ENV}\": $(cat "$OUTPUT_FILE")" >> "$COMBINED_FILE"
    FIRST=false
  fi
done

cat >> "$COMBINED_FILE" <<EOF

}
EOF

if [ "$FIRST" = false ]; then
  echo "✓ Combined outputs saved to: ${COMBINED_FILE}"
else
  echo "✗ No outputs found to combine"
  rm -f "$COMBINED_FILE"
fi

echo ""
echo "=== Export Complete ==="
echo ""
echo "Output files location: ${OUTPUTS_DIR}"
echo ""
echo "To view outputs:"
echo "  cat ${OUTPUTS_DIR}/terraform-outputs-dev.json | jq"
echo ""
echo "To extract specific output:"
echo "  jq -r '.aks_oidc_issuer_url.value' ${OUTPUTS_DIR}/terraform-outputs-dev.json"
