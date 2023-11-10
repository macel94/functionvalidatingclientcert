Import-Module Microsoft.Graph.Applications

$tenantId = "6998af00-286c-4e5e-8b3e-713471e8487f"
$subscriptionId = "6a37c895-4239-4b1e-bc34-a48c4994cc8a"
$functionAppName = "FBelaccaFunctionTest1"
$apiAppName = "$functionAppName-api"
$apiAppIdentifierUri = "api://$functionAppName"
$clientAppName = "$functionAppName-client"

Write-Host "Subscription Id: $subscriptionId"
Write-Host "Function App Name: $functionAppName"
Write-Host "Tenant Id: $tenantId"
Write-Host "Api App Name: $apiAppName"
Write-Host "Api App Identifier Uri: $apiAppIdentifierUri"
Write-Host "Client App Name: $clientAppName"

#az login --tenant $tenantId
Connect-MgGraph -NoWelcome -TenantId $tenantId -Scopes 'Application.ReadWrite.All','AppRoleAssignment.ReadWrite.All','Directory.AccessAsUser.All','Directory.ReadWrite.All'
az account set --subscription $subscriptionId

# Function to ensure service principal creation
function Ensure-ServicePrincipal {
    param (
        [string]$appId
    )

    $sp = Get-MgServicePrincipal -Filter "appId eq '$appId'"
    if (-not $sp) {
        az ad sp create --id $appId
        Start-Sleep -Seconds 10 # Wait for propagation
        $sp = Get-MgServicePrincipal -Filter "appId eq '$appId'"
    }
    return $sp.Id.ToString()
}

$existingApiApp = az ad app list --filter "displayName eq '$apiAppName'" --query "[].appId" -o tsv
if ([string]::IsNullOrEmpty($existingApiApp)) {
    $apiAppId = az ad app create --identifier-uris $apiAppIdentifierUri --display-name $apiAppName --sign-in-audience "AzureADMyOrg" --query "appId" -o tsv
    Write-Host "New Api App Id: $apiAppId"
} else {
    $apiAppId = $existingApiApp
    Write-Host "Existing Api App Id: $apiAppId"
}

$apiEntity = Get-MgApplication -Filter "AppId eq '$apiAppId'"

$appRole = @{
    Id = New-Guid
    AllowedMemberTypes = @("Application")
    DisplayName = "$apiAppName-access"
    IsEnabled = $true
    Description = "Allows applications to access $apiAppName on behalf of the calling app."
    Value = "$apiAppName.ReadWrite"
}

$appRoles = $apiEntity.AppRoles

$existingRole = $appRoles | Where-Object { $_.DisplayName -eq $appRole.DisplayName }

if ($existingRole) {
    # If there are multiple roles with the same display name, assign the first one
    $roleIdToAssign = $existingRole.Id
} else {
    $appRoles += $appRole
    $roleIdToAssign = $appRole.Id
    Update-MgApplicationByAppId -AppId $apiAppId -AppRoles $appRoles
}

$existingClientApp = az ad app list --filter "displayName eq '$clientAppName'" --query "[].appId" -o tsv
if ([string]::IsNullOrEmpty($existingClientApp)) {
    $clientAppId = az ad app create --display-name $clientAppName --sign-in-audience "AzureADMyOrg" --query "appId" -o tsv
    Write-Host "New Client App Id: $clientAppId"
} else {
    $clientAppId = $existingClientApp
    Write-Host "Existing Client App Id: $clientAppId"
}

# Ensure Service Principal for API App
$apiObjectId = Ensure-ServicePrincipal -appId $apiAppId
# Ensure Service Principal for Client App
$clientAppObjectId = Ensure-ServicePrincipal -appId $clientAppId

Write-Host "Client App Object ID: $clientAppObjectId"
Write-Host "API App Object ID: $apiObjectId"

$existingAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $clientAppObjectId

Write-Host "Existing role assignments: $($existingAssignments | ConvertTo-Json -Depth 2)"

if ($existingAssignments.AppRoleId -notcontains $roleIdToAssign) {
    Write-Host "Role ID to Assign: $roleIdToAssign"
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $apiObjectId -PrincipalId $clientAppObjectId -ResourceId $apiObjectId -AppRoleId $roleIdToAssign
} else {
    Write-Host "Role ID $roleIdToAssign is already assigned to the service principal."
}

# Generate a new secret for the existing client app
$clientSecret = az ad app credential reset --id $clientAppId --append --years 2 --query "password" -o tsv

if (-not [string]::IsNullOrEmpty($clientSecret)) {
    Write-Host "Client Secret: $clientSecret"
    Start-Sleep -Seconds 30 # Wait for propagation
} else {
    Write-Host "Client Secret was not generated."
}

# Finally Get a token using clientApp service principal and correct scope
$body = @{
    client_id     = $clientAppId
    scope         = "$apiAppId/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

# Token Endpoint
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# Get the token
$response = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body -ContentType "application/x-www-form-urlencoded"

# Access Token
$token = $response.access_token

# Output the token
Write-Output "Access Token: $token"
# Make a GET REQUEST with the token to "https://fbelacca-test-cv-apim.azure-api.net/FunctionThatValidatesCertificatesInHeader20231106164839/ValidateCertAuth" with the header Authorization: Bearer $tokenResponse without body

$uri = "https://fbelacca-test-cv-apim.azure-api.net/FunctionThatValidatesCertificatesInHeader20231106164839/ValidateCertAuth"
$headers = @{
    "Authorization" = "Bearer $token"
}

$apiresponse = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
Write-Host "Api Response: $apiresponse"