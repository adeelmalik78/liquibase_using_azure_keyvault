# Azure Key Vault + Liquibase Setup Guide

This guide explains how to set up and use the Azure Key Vault integration with Liquibase in GitLab CI/CD.

## Files Created

1. **fetch-liquibase-secrets.sh** - Script to retrieve secrets from Azure Key Vault
2. **.gitlab-ci.yml** - GitLab CI/CD pipeline configuration
3. **azure-keyvault-liquibase-requirements.md** - Complete requirements document

## Prerequisites

### 1. Azure Setup

#### Create Azure Key Vault
```bash
# Create resource group (if needed)
az group create --name liquibase-rg --location eastus

# Create Key Vault
az keyvault create \
  --name LiquibaseSCT \
  --resource-group liquibase-rg \
  --location eastus
```

#### Create Service Principal
```bash
# Create service principal and save the output
az ad sp create-for-rbac \
  --name "GitLab-Liquibase-SP" \
  --role "Key Vault Secrets User" \
  --scopes /subscriptions/{subscription-id}/resourceGroups/liquibase-rg/providers/Microsoft.KeyVault/vaults/LiquibaseSCT

# Output will contain:
# {
#   "appId": "xxxx-xxxx-xxxx-xxxx",           # This is AZURE_CLIENT_ID
#   "password": "xxxx-xxxx-xxxx-xxxx",        # This is AZURE_CLIENT_SECRET
#   "tenant": "xxxx-xxxx-xxxx-xxxx"           # This is AZURE_TENANT_ID
# }
```

#### Add Secrets to Key Vault

For each environment (dev, staging, prod), add the required secrets:

```bash
# Development environment secrets
az keyvault secret set \
  --vault-name LiquibaseSCT \
  --name "liquibase-license-key" \
  --value "YOUR_LIQUIBASE_PRO_LICENSE_KEY"

az keyvault secret set \
  --vault-name LiquibaseSCT \
  --name "dev-liquibase-db-url" \
  --value "jdbc:postgresql://dev-db.example.com:5432/mydb"

az keyvault secret set \
  --vault-name LiquibaseSCT \
  --name "dev-liquibase-db-username" \
  --value "liquibase_user"

az keyvault secret set \
  --vault-name LiquibaseSCT \
  --name "dev-liquibase-db-password" \
  --value "secure_password_here"

# Optional: Changelog file path (if different from default)
az keyvault secret set \
  --vault-name LiquibaseSCT \
  --name "dev-liquibase-changelog-file" \
  --value "db/changelog/db.changelog-master.xml"

# Optional: Database driver class
az keyvault secret set \
  --vault-name LiquibaseSCT \
  --name "dev-liquibase-driver" \
  --value "org.postgresql.Driver"

# Repeat for staging and prod environments
# Use prefixes: staging-liquibase-* and prod-liquibase-*
```

### 2. GitLab Setup

#### Configure GitLab CI/CD Variables

Go to your GitLab project: **Settings → CI/CD → Variables**

Add the following variables (all should be **Protected** and **Masked**):

| Variable Name | Value | Description |
|---------------|-------|-------------|
| `AZURE_CLIENT_ID` | `xxxx-xxxx-xxxx-xxxx` | Service Principal Application ID |
| `AZURE_CLIENT_SECRET` | `xxxx-xxxx-xxxx-xxxx` | Service Principal Password |
| `AZURE_TENANT_ID` | `xxxx-xxxx-xxxx-xxxx` | Azure AD Tenant ID |
| `AZURE_KEYVAULT_NAME` | `LiquibaseSCT` | Name of your Key Vault |

**Important**:
- Check "Protected" to restrict to protected branches only
- Check "Masked" to hide values in job logs
- Do NOT check "Expand variable reference" for secrets

#### Repository Structure

Create the following directory structure in your repository:

```
your-repo/
├── .gitlab-ci.yml
├── scripts/
│   └── fetch-liquibase-secrets.sh
├── changelog.xml
├── main
│   ├── 100_ddl
│   │   ├── 01_sales-rollback.sql
│   │   ├── 01_sales.sql
│   │   ├── 02_employee-rollback.sql
│   │   ├── 02_employee.sql
│   │   ├── 03_contractors-rollback.sql
│   │   └── 03_contractors.sql
│   └── 700_dml
│       ├── Q4-2022_employees-rollback.sql
│       ├── Q4-2022_employees.sql
│       └── Q4-2022_employees2.sql
├── runme.sh
└── .gitignore
```

#### Update .gitignore

Add the following to your `.gitignore`:

```gitignore
# Liquibase properties (contains secrets)
liquibase.properties
**/liquibase.properties

# Liquibase local files
liquibase.*.log
```

## How It Works

### Pipeline Flow

1. **Validation Stage**:
   - Checks if required files exist
   - Validates GitLab CI/CD variables are set
   - Ensures prerequisites are met

2. **Liquibase Stage**:
   - Installs Azure CLI in the container
   - Executes `fetch-liquibase-secrets.sh` script
   - Script authenticates to Azure using Service Principal
   - Fetches secrets from Azure Key Vault
   - Generates `liquibase.properties` file
   - Runs Liquibase with the generated properties
   - Cleans up properties file after execution

### Script Execution

The script is invoked with three arguments:

```bash
./scripts/fetch-liquibase-secrets.sh <keyvault-name> <environment> <output-file>
```

Example:
```bash
./scripts/fetch-liquibase-secrets.sh LiquibaseSCT prod ./liquibase.properties
```

### Generated Properties File

The script generates a `liquibase.properties` file with the following structure:

```properties
# Liquibase Properties - Generated from Azure Key Vault
# Environment: prod
# Generated: 2026-01-26 14:30:00 UTC
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

# Liquibase Pro License
liquibaseProLicenseKey=BASE64_LICENSE_KEY_HERE

# Database Connection
url=jdbc:postgresql://prod-db.example.com:5432/mydb
username=liquibase_user
password=secure_password

# Changelog Configuration
changeLogFile=db/changelog/db.changelog-master.xml
driver=org.postgresql.Driver

# Liquibase Behavior
logLevel=INFO
```

## Usage

### Running Pipelines

#### Development Environment
- Push to `develop` branch
- Pipeline runs automatically
- Applies changes to dev database

#### Staging Environment
- Push to `staging` branch
- Pipeline requires manual approval
- Click "Play" button in GitLab to execute

#### Production Environment
- Push to `main` branch
- Pipeline requires manual approval
- Review changes carefully before executing

### Manual Jobs

#### Rollback Changes
1. Go to CI/CD → Pipelines
2. Find the pipeline you want to rollback
3. Click the "Play" button on `liquibase:rollback` job
4. Set variables if needed (ENVIRONMENT, ROLLBACK_COUNT)

#### Generate SQL for Review
1. Navigate to CI/CD → Pipelines
2. Click "Play" on `liquibase:update-sql` job
3. Download `migration.sql` artifact after completion

#### Validate Changelog
- Automatically runs on merge requests
- Can also be triggered manually

## Testing Locally

### Test the Script Locally

```bash
# Set environment variables
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_TENANT_ID="your-tenant-id"

# Make script executable
chmod +x scripts/fetch-liquibase-secrets.sh

# Run the script
./scripts/fetch-liquibase-secrets.sh LiquibaseSCT dev ./liquibase.properties

# Verify the generated file
cat liquibase.properties

# Clean up
rm liquibase.properties
```

### Test Liquibase Locally

```bash
# After generating properties file
liquibase --defaults-file=./liquibase.properties status
liquibase --defaults-file=./liquibase.properties validate
liquibase --defaults-file=./liquibase.properties update-sql
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failed
```
ERROR: Failed to authenticate to Azure
```
**Solution**: Verify GitLab CI/CD variables are set correctly:
- AZURE_CLIENT_ID
- AZURE_CLIENT_SECRET
- AZURE_TENANT_ID

#### 2. Secret Not Found
```
ERROR: Failed to retrieve secret: dev-liquibase-license-key
```
**Solution**:
- Verify the secret exists in Key Vault
- Check the secret name matches the pattern: `{environment}-liquibase-{property}`
- Ensure Service Principal has "Get" permission on secrets

#### 3. Permission Denied
```
ERROR: The user, group or application does not have secrets get permission
```
**Solution**:
- Grant Service Principal "Key Vault Secrets User" role
- Or add access policy with "Get" permission for secrets

#### 4. Properties File Not Generated
```
ERROR: Properties file was not generated
```
**Solution**:
- Check script execution logs for errors
- Verify script has execute permissions (`chmod +x`)
- Ensure all required secrets are available

#### 5. Liquibase Connection Failed
```
Connection could not be created to jdbc:...
```
**Solution**:
- Verify database URL in Key Vault is correct
- Ensure GitLab runners can reach the database
- Check username and password are correct
- Verify JDBC driver is included in Liquibase image

### Debug Mode

Enable debug output by modifying the script:

```bash
# Add at the top of fetch-liquibase-secrets.sh
set -x  # Enable debug mode
```

**Warning**: Debug mode may expose secrets in logs. Use only in secure environments.

### View Azure Key Vault Access Logs

```bash
# Enable diagnostic settings on Key Vault
az monitor diagnostic-settings create \
  --resource /subscriptions/{sub-id}/resourceGroups/liquibase-rg/providers/Microsoft.KeyVault/vaults/LiquibaseSCT \
  --name KeyVaultAudit \
  --logs '[{"category": "AuditEvent","enabled": true}]' \
  --workspace {log-analytics-workspace-id}

# Query logs
az monitor log-analytics query \
  --workspace {workspace-id} \
  --analytics-query "AzureDiagnostics | where ResourceType == 'VAULTS' | take 20"
```

## Security Best Practices

1. **Rotate Credentials Regularly**
   - Rotate Service Principal secret every 90 days
   - Update GitLab CI/CD variables after rotation

2. **Use Protected Branches**
   - Only allow pipeline execution on protected branches
   - Require code review before merging to main/staging

3. **Monitor Access**
   - Enable Azure Key Vault diagnostic logging
   - Set up alerts for failed authentication attempts
   - Review access logs monthly

4. **Least Privilege**
   - Service Principal should only have "Get" permission for secrets
   - Use separate Service Principals per environment if possible

5. **Network Security**
   - Configure Key Vault firewall rules if needed
   - Use Azure Private Link for enhanced security
   - Whitelist GitLab runner IP addresses

## Maintenance

### Update Secrets

```bash
# Update a secret value
az keyvault secret set \
  --vault-name LiquibaseSCT \
  --name "prod-liquibase-db-password" \
  --value "new_secure_password"

# Verify update
az keyvault secret show \
  --vault-name LiquibaseSCT \
  --name "prod-liquibase-db-password" \
  --query "attributes.updated"
```

### Rotate Service Principal Secret

```bash
# Create new credential
az ad sp credential reset \
  --id {app-id} \
  --years 1

# Update GitLab CI/CD variable AZURE_CLIENT_SECRET with new value
```

### Update Liquibase Version

Edit `.gitlab-ci.yml`:
```yaml
variables:
  LIQUIBASE_VERSION: "4.26"  # Update to desired version
```

## Additional Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Liquibase Documentation](https://docs.liquibase.com/)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Azure Key Vault access logs
3. Check GitLab pipeline logs
4. Contact your DevOps team

## Changelog

- **2026-01-26**: Initial setup guide created
