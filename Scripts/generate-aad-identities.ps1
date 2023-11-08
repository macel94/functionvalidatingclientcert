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
# Check if the app already exists
$existingApiApp = az ad app list --filter "displayName eq '$apiAppName'" --query "[].appId" -o tsv
if ([string]::IsNullOrEmpty($existingApiApp)) {
    Write-Host "API App does not exist. Creating..."
    # Create new app if it doesn't exist
    $apiApp = az ad app create --display-name $apiAppName --identifier-uris $apiAppIdentifierUri --query "appId" -o tsv
    # Generate a new GUID for the permission
    $newPermissionId = [guid]::NewGuid().ToString()
    # Define the new permission in the API app registration
    $apiAppPermissions = @(
        @{
            "allowedMemberTypes" = @("Application");
            "description" = "Access as an application";
            "displayName" = "Access as an application";
            "id" = $newPermissionId;
            "isEnabled" = $true;
            "value" = "access_as_application";
        }
    )
    # Convert to JSON with correct depth
    $jsonApiAppPermissions = $apiAppPermissions | ConvertTo-Json -Depth 10
    # Update the API app registration with the new permission
    az ad app update --id $apiApp --set appRoles=$jsonApiAppPermissions
} else {
    Write-Host "Existing API App: $existingApiApp"
    # Update existing app
    $apiApp = $existingApiApp
    # Uncomment only if needed, useless if the app already has the correct identifier URI
    # az ad app update --id $existingApiApp --identifier-uris $apiAppIdentifierUri
    
    # Generate a new GUID for the permission
    $newPermissionId = [guid]::NewGuid().ToString()
    # Create the appRoles structure as individual objects
    $apiAppPermission = @{
        "allowedMemberTypes" = @("Application");
        "description" = "Access as an application";
        "displayName" = "Access as an application";
        "id" = [guid]::NewGuid().ToString();
        "isEnabled" = $true;
        "value" = $functionAppName + "User";
    }

    # Construct the --set argument in dot-notation format
    $setArgument = "appRoles[0].allowedMemberTypes=`"$($apiAppPermission.allowedMemberTypes[0])`" " +
                "appRoles[0].description=`"$($apiAppPermission.description)`" " +
                "appRoles[0].displayName=`"$($apiAppPermission.displayName)`" " +
                "appRoles[0].id=`"$($apiAppPermission.id)`" " +
                "appRoles[0].isEnabled=`"$($apiAppPermission.isEnabled)`" " +
                "appRoles[0].value=`"$($apiAppPermission.value)`""

    # Update the API app registration with the new permission
    az ad app update --id $apiApp --set $setArgument
}

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
