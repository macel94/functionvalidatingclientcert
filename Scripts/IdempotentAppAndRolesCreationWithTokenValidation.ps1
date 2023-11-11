
Import-Module Microsoft.Graph.Applications

$tenantId = "6998af00-286c-4e5e-8b3e-713471e8487f"
$functionAppName = "FBelaccaFunctionTest1"
$apiAppName = "$functionAppName-api"
$apiAppIdentifierUri = "api://$functionAppName"
$clientAppName = "$functionAppName-client"

Connect-MgGraph -NoWelcome -TenantId $tenantId -Scopes 'Application.ReadWrite.All','AppRoleAssignment.ReadWrite.All','Directory.AccessAsUser.All','Directory.ReadWrite.All'

$existingApiApp = Get-MgApplication -Filter "displayName eq '$apiAppName'"
if ($null -eq $existingApiApp) {
    Write-Host "Creating api app $apiAppName"
    $apiApp = New-MgApplication -DisplayName $apiAppName -IdentifierUris $apiAppIdentifierUri -SignInAudience "AzureADMyOrg"
    $apiAppId = $apiApp.AppId
} else {
    Write-Host "Api app $apiAppName already exists with id $existingApiApp.AppId"
    $apiAppId = $existingApiApp.AppId
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

if ($null -eq $existingRole) {
    Write-Host "Creating role $($appRole.DisplayName)"
    $appRoles += $appRole
    Update-MgApplication -ApplicationId $apiAppId -AppRoles $appRoles
    $roleIdToAssign = $appRole.Id
} else {
    Write-Host "Role $($appRole.DisplayName) already exists with id $($existingRole.Id)"
    $roleIdToAssign = $existingRole.Id
}

$existingClientApp = Get-MgApplication -Filter "displayName eq '$clientAppName'"
if ($null -eq $existingClientApp) {
    Write-Host "Creating client app $clientAppName"
    $clientApp = New-MgApplication -DisplayName $clientAppName -SignInAudience "AzureADMyOrg"
    $clientAppId = $clientApp.AppId
} else {
    Write-Host "Client app $clientAppName already exists with id $($existingClientApp.AppId)"
    $clientAppId = $existingClientApp.AppId
}

# Service Principal Creation
function Confirm-ServicePrincipal {
    param ([string]$appId)
    $sp = Get-MgServicePrincipal -Filter "appId eq '$appId'"
    if ($null -eq $sp) {
        Write-Host "Service Principal not found for appId $appId"
        $sp = New-MgServicePrincipal -AppId $appId
        Start-Sleep -Seconds 10
    }
    else{
        Write-Host "Service Principal found for appId $appId"
    }
    return $sp.Id
}

$apiServicePrincipalId = Confirm-ServicePrincipal -appId $apiAppId
$clientAppServicePrincipalId = Confirm-ServicePrincipal -appId $clientAppId

$existingAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $clientAppServicePrincipalId
if ($existingAssignments.AppRoleId -notcontains $roleIdToAssign) {
    Write-Host "Assigning role $roleIdToAssign to $clientAppServicePrincipalId"
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $apiServicePrincipalId -PrincipalId $clientAppServicePrincipalId -ResourceId $apiServicePrincipalId -AppRoleId $roleIdToAssign
}
else {
    Write-Host "Role $roleIdToAssign already assigned to $clientAppServicePrincipalId"
}

# Add Client Secret to the Client App
$passwordCred = @{
    "displayName" = "ClientSecretFor$functionAppName"
    "endDateTime" = (Get-Date).AddYears(2)
}
# Here we need to use the clientObjectId of the clientApp so we make a get
# Retrieve the client application entity
$clientAppEntity = Get-MgApplication -Filter "AppId eq '$clientAppId'"

Write-Host "Creating secret for client app named $clientAppName with objectId $($clientAppEntity.Id)"

# Use the Id of the client application when adding the password
$clientSecret = Add-MgApplicationPassword -ApplicationId $($clientAppEntity.Id) -PasswordCredential $passwordCred

if ($null -ne $clientSecret.SecretText) {
    Write-Host "Secret created: $($clientSecret.SecretText), waiting 10 seconds for replication"
    Start-Sleep -Seconds 10
}
else {
    Write-Host "Secret not created"
}

# Finally Get a token using clientApp service principal and correct scope
$body = @{
    client_id     = $clientAppId
    scope         = "$apiAppId/.default"
    client_secret = $clientSecret.SecretText
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