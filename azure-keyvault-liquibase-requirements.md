# Azure Key Vault with Liquibase - Requirements Document

## Overview
This document outlines the requirements and implementation approach for integrating Azure Key Vault with Liquibase running in GitLab CI/CD pipelines. The solution enables secure storage and retrieval of sensitive Liquibase properties including license keys, database credentials, and connection strings.

## Objectives
- Store all sensitive Liquibase properties securely in Azure Key Vault
- Fetch secrets dynamically during GitLab CI/CD pipeline execution
- Populate Liquibase properties file at runtime with retrieved secrets
- Maintain security best practices and minimize credential exposure

## Architecture Components

### 1. Azure Key Vault
- **Purpose**: Centralized secure storage for sensitive configuration
- **Secrets to Store**:
  - `liquibase-pro-license-key`: Liquibase Pro license key
  - `database-url`: JDBC connection string
  - `database-username`: Database username
  - `database-password`: Database password
  - Additional environment-specific secrets as needed

### 2. Azure Service Principal
- **Purpose**: Authentication mechanism for GitLab pipeline to access Key Vault
- **Required Permissions**:
  - Key Vault Secrets User (Get, List)
  - Minimum privilege access to specific secrets only

### 3. GitLab CI/CD Pipeline
- **Purpose**: Orchestrate Liquibase execution with secrets from Azure Key Vault
- **Components**:
  - Secret retrieval script
  - Liquibase properties population
  - Liquibase execution

### 4. Liquibase
- **Configuration**: Properties-based configuration
- **Execution Mode**: Command-line execution in containerized environment

## Prerequisites

### Azure Requirements
1. Active Azure subscription
2. Azure Key Vault instance created
3. Service Principal with appropriate permissions
4. Network access configured (if using private endpoints)

### GitLab Requirements
1. GitLab CI/CD enabled for repository
2. GitLab CI/CD variables configured:
   - `AZURE_CLIENT_ID`: Service Principal Application ID
   - `AZURE_CLIENT_SECRET`: Service Principal Secret (masked/protected)
   - `AZURE_TENANT_ID`: Azure AD Tenant ID
   - `AZURE_KEYVAULT_NAME`: Name of the Key Vault instance

### Technical Requirements
1. Azure CLI or Azure SDK availability in pipeline runner
2. Liquibase installed or available as container image
3. Network connectivity from GitLab runners to Azure Key Vault

## Implementation Requirements

### 1. Azure Key Vault Setup

#### Secret Naming Convention
Use consistent naming for secrets to enable easy scripting:
- Format: `{environment}-{application}-{property}`
- Examples:
  - `prod-liquibase-license-key`
  - `prod-liquibase-db-url`
  - `prod-liquibase-db-username`
  - `prod-liquibase-db-password`
  - `dev-liquibase-license-key`
  - `dev-liquibase-db-url`

#### Access Policies
Configure Key Vault access policy or RBAC:
```
Principal: GitLab Service Principal
Permissions:
  - Get (Secrets)
  - List (Secrets) - optional, only if needed
```

### 2. Secret Retrieval Script

#### Script Requirements
Create a shell/bash script with the following capabilities:

**Input Parameters**:
- Azure Key Vault name
- Environment identifier (dev/staging/prod)
- Output file path for Liquibase properties

**Authentication**:
- Use Azure Service Principal credentials
- Support for Azure CLI or Azure REST API

**Functionality**:
1. Authenticate to Azure using Service Principal
2. Fetch required secrets from Key Vault
3. Generate liquibase.properties file with retrieved values
4. Ensure secure handling (no secrets in logs)
5. Validate all required secrets are retrieved
6. Exit with appropriate error codes

**Error Handling**:
- Fail pipeline if any required secret is missing
- Provide clear error messages
- No secret values in error output

**Example Script Structure**:
```bash
#!/bin/bash
# fetch-liquibase-secrets.sh

# Input validation
KEYVAULT_NAME=$1
ENVIRONMENT=$2
OUTPUT_FILE=$3

# Authenticate to Azure
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Fetch secrets
LICENSE_KEY=$(az keyvault secret show --vault-name $KEYVAULT_NAME \
  --name "${ENVIRONMENT}-liquibase-license-key" --query value -o tsv)

DB_URL=$(az keyvault secret show --vault-name $KEYVAULT_NAME \
  --name "${ENVIRONMENT}-liquibase-db-url" --query value -o tsv)

DB_USERNAME=$(az keyvault secret show --vault-name $KEYVAULT_NAME \
  --name "${ENVIRONMENT}-liquibase-db-username" --query value -o tsv)

DB_PASSWORD=$(az keyvault secret show --vault-name $KEYVAULT_NAME \
  --name "${ENVIRONMENT}-liquibase-db-password" --query value -o tsv)

# Generate liquibase.properties
cat > $OUTPUT_FILE <<EOF
liquibaseProLicenseKey=${LICENSE_KEY}
url=${DB_URL}
username=${DB_USERNAME}
password=${DB_PASSWORD}
changeLogFile=db/changelog/db.changelog-master.xml
EOF

# Cleanup
az logout
```

### 3. GitLab CI/CD Pipeline Configuration

#### Required Stages
1. **Fetch Secrets**: Retrieve secrets from Azure Key Vault
2. **Run Liquibase**: Execute Liquibase with populated properties

#### Pipeline Variables
Configure in GitLab (Settings > CI/CD > Variables):
- `AZURE_CLIENT_ID` (Protected, Masked)
- `AZURE_CLIENT_SECRET` (Protected, Masked)
- `AZURE_TENANT_ID` (Protected, Masked)
- `AZURE_KEYVAULT_NAME` (Protected)

#### Example .gitlab-ci.yml Structure
```yaml
stages:
  - liquibase

variables:
  ENVIRONMENT: "dev"  # Override per branch/environment

liquibase:update:
  stage: liquibase
  image: liquibase/liquibase:latest
  before_script:
    # Install Azure CLI
    - apk add --no-cache python3 py3-pip
    - pip3 install --upgrade pip
    - pip3 install azure-cli

    # Fetch secrets and generate properties file
    - chmod +x ./scripts/fetch-liquibase-secrets.sh
    - ./scripts/fetch-liquibase-secrets.sh
        $AZURE_KEYVAULT_NAME
        $ENVIRONMENT
        ./liquibase.properties

  script:
    - liquibase --defaults-file=./liquibase.properties update

  after_script:
    # Cleanup sensitive files
    - rm -f ./liquibase.properties

  only:
    - main
    - develop
```

### 4. Liquibase Properties File

#### Generated Format
The script should generate a properties file with the following structure:
```properties
liquibaseProLicenseKey=<from-keyvault>
url=<from-keyvault>
username=<from-keyvault>
password=<from-keyvault>
changeLogFile=db/changelog/db.changelog-master.xml
driver=<database-driver-class>
classpath=<jdbc-driver-path>
```

#### File Handling
- Generate at runtime only
- Store in temporary location
- Delete after pipeline completion
- Never commit to version control
- Add to .gitignore

## Security Requirements

### Authentication & Authorization
1. Use Service Principal authentication only
2. Apply principle of least privilege
3. Rotate Service Principal secrets regularly (90 days recommended)
4. Use separate Service Principals per environment if possible

### Secret Management
1. All secrets must be stored in Azure Key Vault
2. No secrets in GitLab repository files
3. GitLab variables must be masked and protected
4. Enable Key Vault audit logging
5. Monitor Key Vault access patterns

### Pipeline Security
1. Restrict pipeline execution to protected branches
2. Use specific container image versions (avoid :latest in production)
3. Implement pipeline approval gates for production
4. Clean up generated properties files in after_script
5. Disable debug logging that might expose secrets

### Network Security
1. Configure Key Vault firewall rules if applicable
2. Use private endpoints for Key Vault if required
3. Ensure GitLab runners can reach Azure endpoints

## Environment-Specific Configurations

### Development Environment
- Key Vault: `keyvault-dev-liquibase`
- Secret Prefix: `dev-liquibase-*`
- Database: Development database instance

### Staging Environment
- Key Vault: `keyvault-staging-liquibase` or use same vault with prefix
- Secret Prefix: `staging-liquibase-*`
- Database: Staging database instance

### Production Environment
- Key Vault: `keyvault-prod-liquibase` or use same vault with prefix
- Secret Prefix: `prod-liquibase-*`
- Database: Production database instance
- Additional requirements:
  - Manual approval for pipeline execution
  - Enhanced monitoring and alerting
  - Backup verification before execution

## Validation & Testing

### Pre-Deployment Testing
1. Verify Service Principal has correct permissions
2. Test secret retrieval script locally
3. Validate generated properties file format
4. Test Liquibase connectivity with retrieved credentials

### Pipeline Testing
1. Test in development environment first
2. Verify secrets are not exposed in pipeline logs
3. Confirm properties file is cleaned up
4. Validate Liquibase executes successfully

### Monitoring
1. Enable Azure Key Vault diagnostic logs
2. Monitor Key Vault access failures
3. Track GitLab pipeline success/failure rates
4. Alert on authentication failures

## Rollback Procedures

### Failed Secret Retrieval
1. Pipeline fails automatically
2. No database changes applied
3. Investigate Key Vault access issues

### Failed Liquibase Execution
1. Review Liquibase error messages
2. Verify database connectivity
3. Check changelog file syntax
4. Use Liquibase rollback commands if needed

## Documentation Requirements

### Operational Documentation
1. Service Principal creation and rotation procedure
2. Adding new secrets to Key Vault
3. Updating GitLab CI/CD variables
4. Troubleshooting common issues

### Developer Documentation
1. How to run Liquibase locally (with local properties)
2. Pipeline execution process
3. Environment promotion workflow
4. Emergency access procedures

## Maintenance Requirements

### Regular Maintenance
1. Review and rotate Service Principal credentials quarterly
2. Audit Key Vault access logs monthly
3. Update Azure CLI and Liquibase versions
4. Review and update secret values as needed

### Compliance
1. Maintain audit trail of secret access
2. Document secret rotation procedures
3. Regular security reviews
4. Compliance with organizational policies

## Risk Assessment

### Potential Risks
1. **Service Principal Compromise**: Implement secret rotation and monitoring
2. **Key Vault Unavailability**: Implement retry logic and alerting
3. **Network Connectivity Issues**: Configure appropriate timeouts and fallbacks
4. **Secret Exposure in Logs**: Implement log sanitization and review

### Mitigation Strategies
1. Enable Azure MFA for Key Vault management access
2. Implement IP restrictions on Key Vault if possible
3. Use separate Key Vaults per environment for isolation
4. Regular security audits and penetration testing

## Success Criteria

### Functional Requirements
- [ ] Liquibase successfully retrieves all required properties from Azure Key Vault
- [ ] GitLab pipeline executes Liquibase with fetched credentials
- [ ] No secrets stored in GitLab repository or visible in logs
- [ ] Properties file generated and cleaned up properly

### Non-Functional Requirements
- [ ] Secret retrieval completes within 30 seconds
- [ ] Pipeline execution time increased by no more than 1 minute
- [ ] Zero secret exposure incidents
- [ ] 99.9% pipeline success rate (excluding Liquibase changelog errors)

## Appendix

### Useful Commands

#### Azure CLI - Create Service Principal
```bash
az ad sp create-for-rbac --name "GitLab-Liquibase-SP" \
  --role "Key Vault Secrets User" \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{keyvault-name}
```

#### Azure CLI - Add Secret to Key Vault
```bash
az keyvault secret set \
  --vault-name {keyvault-name} \
  --name "prod-liquibase-license-key" \
  --value "{license-key-value}"
```

#### Azure CLI - Test Secret Retrieval
```bash
az keyvault secret show \
  --vault-name {keyvault-name} \
  --name "prod-liquibase-license-key" \
  --query value -o tsv
```

### Reference Links
- Azure Key Vault Documentation: https://docs.microsoft.com/azure/key-vault/
- Liquibase Documentation: https://docs.liquibase.com/
- GitLab CI/CD Documentation: https://docs.gitlab.com/ee/ci/
- Azure Service Principal: https://docs.microsoft.com/azure/active-directory/develop/app-objects-and-service-principals

## Version History
- v1.0 - Initial requirements document
