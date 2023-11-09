Import-Module AzureAD -UseWindowsPowerShell

# Install-Module -Name AzureAD -AllowClobber -Force
$subscriptionId = "6a37c895-4239-4b1e-bc34-a48c4994cc8a"
$functionAppName = "FunctionThatValidatesCertificatesInHeaderFBelacca1"
$tenantId = "6998af00-286c-4e5e-8b3e-713471e8487f"


# Log in to Azure
#az login --tenant $tenantId
az account set --subscription $subscriptionId

# Register or update API application in Azure AD
$apiAppName = "$functionAppName-api"
$apiAppIdentifierUri = "api://$functionAppName"
Write-Host "API App Name: $apiAppName"
Write-Host "API App Identifier URI: $apiAppIdentifierUri"
# Log in to AzureAD PowerShell module
Connect-AzureAD -TenantId $tenantId

# Create an application role of given name and description
Function CreateAppRole([string] $Name, [string] $Description) {
    $appRole = New-Object Microsoft.Open.AzureAD.Model.AppRole
    $appRole.AllowedMemberTypes = New-Object System.Collections.Generic.List[string]
    $appRole.AllowedMemberTypes.Add("Application")
    $appRole.DisplayName = $Name
    $appRole.Id = New-Guid
    $appRole.IsEnabled = $true
    $appRole.Description = $Description
    $appRole.Value = $Name
    return $appRole
}

# Fetch the application object by ID
$app = Get-AzureADApplication -Filter "appId eq '$existingApiApp'"

# If the application doesn't have any roles, initialize an empty list
if (-not $app.AppRoles) {
    $app.AppRoles = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.AppRole]
}

# Create a new application role
$newRole = CreateAppRole -Name "$functionAppName-access" -Description "Allows applications to access $functionAppName on behalf of the calling app."

# Add the new role to the current list of app roles
$appRoles = $app.AppRoles
$appRoles.Add($newRole)

# Update the application with the new set of app roles
Set-AzureADApplication -ObjectId $app.ObjectId -AppRoles $appRoles

Write-Host "Updated app roles for $apiAppName with AzureAD PowerShell Module"

# # Register or update client application in Azure AD
# $clientAppName = "$functionAppName-client"
# Write-Host "Client App Name: $clientAppName"
# # Check if the app already exists
# $existingClientApp = az ad app list --filter "displayName eq '$clientAppName'" --query "[].appId" -o tsv
# Write-Host "Existing Client App: $existingClientApp"
# if ([string]::IsNullOrEmpty($existingClientApp)) {
#     # Create new app if it doesn't exist
#     $clientApp = az ad app create --display-name $clientAppName --query "appId" -o tsv
# } else {
#     # Update existing app
#     $clientApp = $existingClientApp
# }

# # Generate a new secret for the existing client app
# $clientSecret = az ad app credential reset --id $clientApp --append --years 2 --credential-description "ClientCredential" --query "password" -o tsv

# if (-not [string]::IsNullOrEmpty($clientSecret)) {
#     Write-Host "Client Secret: $clientSecret"
# } else {
#     Write-Host "Client Secret was not generated."
# }

# # Add the API permissions to the client app (application permissions, not delegated)
# # Replace '<your-exposed-api-permission-id>' with the actual permission ID for your API app
# az ad app permission add --id $clientApp --api $apiApp --api-permissions $newPermissionId=Role

# # Grant admin consent for the permissions to take effect
# az ad app permission grant --id $clientApp --api $apiApp --scope "access_as_application"
# az ad app permission admin-consent --id $clientApp

# # Authenticate using the service principal
# az login --service-principal --username $clientApp --password $clientSecret --tenant $tenantId
# $tokenResponse = az account get-access-token --query "accessToken" -o tsv
# if (-not [string]::IsNullOrEmpty($tokenResponse)) {
#     Write-Host "Access token: $tokenResponse"
# } else {
#     Write-Host "Access token was not generated."
# }