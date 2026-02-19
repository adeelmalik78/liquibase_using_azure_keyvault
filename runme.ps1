# Steps to Find Your AZURE_CLIENT_ID:
# * Sign in to the Azure Portal.
# * Navigate to Microsoft Entra ID (formerly Azure Active Directory).
# * Click on App registrations in the left menu.
# * Select the application you are using.
# * The Application (client) ID is displayed on the Overview blade.
#
# If you are using a Managed Identity, the client ID can be found under the identity's properties or retrieved via the Azure IMDS endpoint.
$env:AZURE_CLIENT_ID="<YOUR AZURE_CLIENT_ID>"

# You can find or reset it in the Azure Portal under
# Microsoft Entra ID > Manage > App Registrations > [Your App Name] > Certificates & secrets.
$env:AZURE_CLIENT_SECRET="<YOUR AZURE_CLIENT_SECRET>"

# Your Azure Tenant ID, needed for Key Vault authentication, is a GUID
# found in the Microsoft Entra ID portal under Properties as "Directory ID"
$env:AZURE_TENANT_ID="<YOUR AZURE_TENANT_ID>"


$scriptOutput= bash.exe scripts/fetch-secrets-using-powershell.sh LiquibaseSCT dev

# Set new environment variables
foreach ($line in $scriptOutput) {
    if ($line -match "^(.+)=(.+)$") {
        $varName = $matches[1]
        $varValue = $matches[2]
        # Set the environment variable in the current PowerShell session
        Set-Item -Path Env:\$varName -Value $varValue
        # Write-Host "Set environment variable: $varName = $varValue"
    }
}

