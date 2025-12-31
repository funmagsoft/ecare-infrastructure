#!/usr/bin/env bash
# Global project configuration variables
# These are project-specific constants and should not be changed per deployment

# Organization name (used for GitHub repository naming)
ORGANIZATION="hycom"

# Organization name for Storage Account naming (may differ from ORGANIZATION due to Azure naming constraints)
ORGANIZATION_FOR_SA="hycom"

# Project name (used for resource naming)
PROJECT="ecare"

# Deployment IDs per environment (8 lowercase alphanumeric characters)
# These IDs are used for resource tagging and cleanup operations
# IMPORTANT: Use the SAME deployment_id across all phases (foundation/identity/platform) for each environment
declare -A DEPLOYMENT_IDS=(
  ["dev"]="a1b2c3d4"
  ["test"]="e5f6g7h8"
  ["stage"]="i9j0k1l2"
  ["prod"]="m3n4o5p6"
)
