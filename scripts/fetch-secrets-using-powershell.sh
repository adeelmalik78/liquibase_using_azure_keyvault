#!/bin/bash

################################################################################
# Script: fetch-liquibase-secrets.sh
# Description: Fetches Liquibase properties from Azure Key Vault and generates
#              a liquibase.properties file for runtime use
# Usage: ./fetch-liquibase-secrets.sh <keyvault-name> <environment> <output-file>
################################################################################

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

# Function to print success messages
success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Function to print info messages
info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

# Validate input parameters
if [ $# -ne 2 ]; then
    error "Invalid number of arguments"
    echo "Usage: $0 <keyvault-name> <environment>"
    echo "Example: $0 my-keyvault prod"
    exit 1
fi

KEYVAULT_NAME=$1
ENVIRONMENT=$2
OUTPUT_FILE="liquibase-${ENVIRONMENT}.properties"

info "Starting secret retrieval from Azure Key Vault..."
info "Key Vault: ${KEYVAULT_NAME}"
info "Environment: ${ENVIRONMENT}"
info "Output File: ${OUTPUT_FILE}"

# Validate required environment variables for Azure authentication
if [ -z "${AZURE_CLIENT_ID:-}" ]; then
    error "AZURE_CLIENT_ID environment variable is not set"
    exit 1
fi

if [ -z "${AZURE_CLIENT_SECRET:-}" ]; then
    error "AZURE_CLIENT_SECRET environment variable is not set"
    exit 1
fi

if [ -z "${AZURE_TENANT_ID:-}" ]; then
    error "AZURE_TENANT_ID environment variable is not set"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    error "Azure CLI is not installed. Please install it first."
    exit 1
fi

info "Azure CLI version: $(az version --query '\"azure-cli\"' -o tsv 2>/dev/null || echo 'unknown')"

# Authenticate to Azure using Service Principal
info "Authenticating to Azure..."
if az login --service-principal \
    --username "${AZURE_CLIENT_ID}" \
    --password "${AZURE_CLIENT_SECRET}" \
    --tenant "${AZURE_TENANT_ID}" \
    --output none 2>/dev/null; then
    success "Authenticated to Azure successfully"
else
    error "Failed to authenticate to Azure"
    exit 1
fi

# Function to fetch secret from Key Vault
fetch_secret() {
    local secret_name=$1
    local secret_value

    # info "Fetching secret: ${secret_name}"

    if secret_value=$(az keyvault secret show \
        --vault-name "${KEYVAULT_NAME}" \
        --name "${secret_name}" \
        --query value \
        --output tsv 2>&1); then

        if [ -z "${secret_value}" ]; then
            error "Secret '${secret_name}' is empty"
            return 1
        fi

        # success "Retrieved secret: ${secret_name}"
        echo "${secret_value}"
        return 0
    else
        error "Failed to retrieve secret: ${secret_name}"
        error "Error details: ${secret_value}"
        return 1
    fi
}

# Define secret names based on environment
LICENSE_KEY_SECRET="liquibase-license-key"
DB_URL_SECRET="${ENVIRONMENT}-liquibase-db-url"
DB_USERNAME_SECRET="${ENVIRONMENT}-liquibase-db-username"
DB_PASSWORD_SECRET="${ENVIRONMENT}-liquibase-db-password"
CHANGELOG_FILE_SECRET="changelog-file"

# Fetch required secrets
info "Fetching required secrets..."

LICENSE_KEY=$(fetch_secret "${LICENSE_KEY_SECRET}") || echo "Failed to fetch license key"
DB_URL=$(fetch_secret "${DB_URL_SECRET}") || echo "Failed to fetch url"
DB_USERNAME=$(fetch_secret "${DB_USERNAME_SECRET}") || echo "Failed to fetch username"
DB_PASSWORD=$(fetch_secret "${DB_PASSWORD_SECRET}") || echo "Failed to fetch password"
CHANGELOG_FILE=$(fetch_secret "${CHANGELOG_FILE_SECRET}") || echo "Failed to fetch changelog file"

success "All required secrets retrieved successfully"

# Setting environment variables
echo "LIQUIBASE_LICENSE_KEY=${LICENSE_KEY}"
echo "LIQUIBASE_COMMAND_URL=${DB_URL}"
echo "LIQUIBASE_COMMAND_USERNAME=${DB_USERNAME}"
echo "LIQUIBASE_COMMAND_PASSWORD=${DB_PASSWORD}"
echo "LIQUIBASE_COMMAND_CHANGELOG_FILE=${CHANGELOG_FILE}"


# Logout from Azure
info "Logging out from Azure..."
az logout --output none 2>/dev/null || true


