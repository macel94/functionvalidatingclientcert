Import-Module AzureAD.Standard.Preview

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

$tenantId = "6998af00-286c-4e5e-8b3e-713471e8487f"
$subscriptionId = "6a37c895-4239-4b1e-bc34-a48c4994cc8a"
$functionAppName = "FBelaccaFunctionTest1"
# $clientAppId = "3150920d-aaa5-4069-96f2-a0ded22ed7a4"
$apiAppName = "$functionAppName-api"
$apiAppIdentifierUri = "api://$functionAppName"
$clientAppName = "$functionAppName-client"

# Print each variable
Write-Host "Subscription Id: $subscriptionId"
Write-Host "Function App Name: $functionAppName"
Write-Host "Tenant Id: $tenantId"
# Write-Host "Client App Id: $clientAppId"
Write-Host "Api App Name: $apiAppName"
Write-Host "Api App Identifier Uri: $apiAppIdentifierUri"
Write-Host "Client App Name: $clientAppName"

# Log in to Azure
#az login --tenant $tenantId
#Connect-AzureAD -TenantId $tenantId 

az account set --subscription $subscriptionId


# Check if the api already exists
$existingApiApp = az ad app list --filter "displayName eq '$apiAppName'" --query "[].appId" -o tsv
if ([string]::IsNullOrEmpty($existingApiApp)) {
    # Create new app if it doesn't exist
    $apiAppId = az ad app create --identifier-uris $apiAppIdentifierUri --display-name $apiAppName --sign-in-audience "AzureADMyOrg" --query "appId" -o tsv
    Write-Host "New Api App Id: $apiAppId"
} else {
    # Update existing app
    $apiAppId = $existingApiApp
    Write-Host "Existing Api App Id: $apiAppId"
}

# Fetch the application object by ID
$apiAppEntity = Get-AzureADApplication -Filter "appId eq '$apiAppId'"

# If the application doesn't have any roles, initialize an empty list
if (-not $apiAppEntity.AppRoles) {
    $apiAppEntity.AppRoles = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.AppRole]
}

# Create a new application role
$newRole = CreateAppRole -Name "$apiAppName-access" -Description "Allows applications to access $apiAppName on behalf of the calling app."

# Add the new role to the current list of app roles
$apiAppRoles = $apiAppEntity.AppRoles
$apiAppRoles.Add($newRole)

Set-AzureADApplication -ObjectId $apiAppEntity.ObjectId -AppRoles $apiAppRoles

Write-Host "Updated app roles for $apiAppName with AzureAD PowerShell Module adding role: $newRole"

# Check if the app already exists
$existingClientApp = az ad app list --filter "displayName eq '$clientAppName'" --query "[].appId" -o tsv
if ([string]::IsNullOrEmpty($existingClientApp)) {
    # Create new app if it doesn't exist, limiting accounts to only users in the tenant
    $clientAppId = az ad app create --display-name $clientAppName --sign-in-audience "AzureADMyOrg" --query "appId" -o tsv
    Write-Host "New Client App Id: $clientAppId"
} else {
    # Update existing app
    $clientAppId = $existingClientApp
    Write-Host "Existing Client App Id: $clientAppId"
}

# Fetch the application object by ID
$clientAppEntity = Get-AzureADApplication -Filter "appId eq '$clientAppId'"

# I managed to manually assign appRole to it 
# $apiId GET https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq '$apiAppid'&$select=id
# $clientId GET https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq '$clientAppId'&$select=id
# POST https://graph.microsoft.com/v1.0/servicePrincipals/$clientId/appRoleAssignments
# {
#     "principalId": "$clientId",
#     "resourceId": "$apiId",
#     "appRoleId": "$newRole.Id"
# }
# Make a POST
$body = @{
    principalId = $clientAppEntity.ObjectId
    resourceId = $apiAppEntity.ObjectId
    appRoleId = $newRole.Id
}

Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($clientAppEntity.ObjectId)/appRoleAssignments" -Body $body -ContentType "application/json"

# # Generate a new secret for the existing client app
# $clientSecret = az ad app credential reset --id $clientAppId --append --years 2 --credential-description "ClientCredential" --query "password" -o tsv

# if (-not [string]::IsNullOrEmpty($clientSecret)) {
#     Write-Host "Client Secret: $clientSecret"
# } else {
#     Write-Host "Client Secret was not generated."
# }

# # Finally Get a token using clientApp service principal and correct scope
# $body = @{
#     client_id     = $clientAppId
#     scope         = "$apiAppId/.default"
#     client_secret = $clientSecret
#     grant_type    = "client_credentials"
# }

# # Token Endpoint
# $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# # Get the token
# $response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType "application/x-www-form-urlencoded"

# # Access Token
# $token = $response.access_token

# # Output the token
# Write-Output "Access Token: $token"
# # Make a GET REQUEST with the token to "https://fbelacca-test-cv-apim.azure-api.net/FunctionThatValidatesCertificatesInHeader20231106164839/ValidateCertAuth" with the header Authorization: Bearer $tokenResponse without body

# $uri = "https://fbelacca-test-cv-apim.azure-api.net/FunctionThatValidatesCertificatesInHeader20231106164839/ValidateCertAuth"
# $headers = @{
#     "Authorization" = "Bearer $token"
# }

# $apiresponse = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
# Write-Host "Api Response: $apiresponse"