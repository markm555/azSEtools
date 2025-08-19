# Service Principal credentials
$tenantId = "<TenantID>"
$clientId = "<ClientID>"
$clientSecret = "<Secret>"
$capacityId = "<FabricCapacityID>"


# Get access token for Power BI API
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = "https://analysis.windows.net/powerbi/api/.default"
}

$tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $tokenBody
$accessToken = $tokenResponse.access_token

# Call the Fabric Admin API to get capacity users
$uri = "https://api.powerbi.com/v1.0/myorg/admin/capacities/$capacityId/users"

$response = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $accessToken" } -Method GET

# Display the results
$response.value | Format-Table


$response.value | Format-Table
