connect-azaccount
$azContext = Get-AzContext
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$authHeader = @{
    'Content-Type'='application/json'
    'Authorization'='Bearer ' + $token.AccessToken
}
# Invoke the REST API
$restUri = "https://management.azure.com/subscriptions/$($azContext.Subscription.Id)?api-version=2020-01-01"
$response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader
$queryUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"
$querybody1 = @{
   'subscritpons'='bed50989-7a45-4b7d-8909-38e8faebec77'
    'query'='Resources |where type =~ "microsoft.azurearcdata/sqlserverinstances" | project name, type, properties.currentVersion, properties.vCore'
} |ConvertTo-Json
$queryresp1 = Invoke-RestMethod -Uri $queryUri -Method "Post" -Body $querybody1 -Headers $authHeader
$rows = @( [PSCustomObject]@{Name="Name"; Version="Version"; RID="Resource ID"; Cores="Cores"})
# Initialize the rows array without headers
$rows = @()
# Process each result and add to the rows array
foreach ($r in $queryresp1.data) {
    $currentVersion = $r.properties_currentVersion
    $major_version = $currentVersion -split '\.' | Select-Object -First 1
    if ($major_version -eq 11) 
    {
        $azres = get-azresource -name $r.name
        $name = $r.name
        $RID = $azres.ResourceId | Where-Object { $_ -match "SqlServerInstances" }
        $VCore = $r.properties_vCore
        $newRow = [PSCustomObject]@{
            Name = $name
            Version = $major_version
            RID = $RID
            Cores = $VCore
        }
        $rows += $newRow
    }
}
# Export the results array to a CSV file
$rows | Export-Csv -Path "SQLESU.csv" -NoTypeInformation
