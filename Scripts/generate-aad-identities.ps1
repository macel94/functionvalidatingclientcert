# Your provided data
$subscriptionId = "6a37c895-4239-4b1e-bc34-a48c4994cc8a"
$functionAppName = "FunctionThatValidatesCertificatesInHeaderFBelacca"
$apim = "https://fbelacca-test-cv-apim.azure-api.net"
$tenantId = "6998af00-286c-4e5e-8b3e-713471e8487f"

# Log in to Azure
# az login --tenant $tenantId
az account set --subscription $subscriptionId

# Register or update API application in Azure AD
$apiAppName = "$functionAppName-api"
$apiAppIdentifierUri = "api://$functionAppName"
$scope = "$apiAppIdentifierUri/.default" # The default scope for application permissions
Write-Host "API App Name: $apiAppName"
Write-Host "API App Identifier URI: $apiAppIdentifierUri"
Write-Host "API App Scope: $scope"
# Check if the app already exists
$existingApiApp = az ad app list --filter "displayName eq '$apiAppName'" --query "[].appId" -o tsv
Write-Host "Existing API App: $existingApiApp"
if ([string]::IsNullOrEmpty($existingApiApp)) {
    # Create new app if it doesn't exist
    $apiApp = az ad app create --display-name $apiAppName --identifier-uris $apiAppIdentifierUri --query "appId" -o tsv
} else {
    # Update existing app
    $apiApp = $existingApiApp
    az ad app update --id $existingApiApp --identifier-uris $apiAppIdentifierUri
}

# Register or update client application in Azure AD
$clientAppName = "$functionAppName-client"
Write-Host "Client App Name: $clientAppName"
# Check if the app already exists
$existingClientApp = az ad app list --filter "displayName eq '$clientAppName'" --query "[].appId" -o tsv
Write-Host "Existing Client App: $existingClientApp"
if ([string]::IsNullOrEmpty($existingClientApp)) {
    # Create new app if it doesn't exist
    $clientApp = az ad app create --display-name $clientAppName --query "appId" -o tsv
} else {
    # Update existing app
    $clientApp = $existingClientApp
}
# Generate a new secret for the existing client app
$clientSecret = az ad app credential reset --id $clientApp --append --years 2 --credential-description "ClientCredential" --query "password" -o tsv

# Output the details needed for OAuth
Write-Host "API Application ID: $apiApp"
Write-Host "Client Application ID: $clientApp"
if (-not [string]::IsNullOrEmpty($clientSecret)) {
    Write-Host "Client Secret: $clientSecret"
} else {
    Write-Host "Client Secret was not generated."
}

# Add the API permissions to the client app (application permissions, not delegated)
az ad app permission add --id $clientApp --api $apiAppId --api-permissions "<your-exposed-api-permission-id>=Role"

# Grant admin consent for the permissions to take effect
az ad app permission admin-consent --id $clientApp

az login --service-principal --username $clientApp --password $clientSecret --tenant $tenantId
$tokenResponse = az account get-access-token --query "accessToken" -o tsv
if (-not [string]::IsNullOrEmpty($tokenResponse)) {
    Write-Host "Access token: $tokenResponse"
} else {
    Write-Host "Access token was not generated."
}