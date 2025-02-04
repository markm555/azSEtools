connect-azaccount
# Invoke the REST API
$restUri = "https://management.azure.com/subscriptions/$($azContext.Subscription.Id)?api-version=2020-01-01"
$response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader

$queryUri = "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"

$querybody1 = @{
   'subscritpons'='bed50989-7a45-4b7d-8909-38e8faebec77'
    'query'='Resources |where type =~ "microsoft.azurearcdata/sqlserverinstances" | project name, type, properties.currentVersion'
} |ConvertTo-Json

$queryresp1 = Invoke-RestMethod -Uri $queryUri -Method "Post" -Body $querybody1 -Headers $authHeader

foreach($resp in $queryresp1.data)
{
    foreach($r in $resp)
    {   
    $name = $r.name
    $currentVersion = $r.properties_currentVersion
    $major_version = $CurrentVersion -split '\.' | Select-Object -First 1
    if($major_version -eq 11)
        {
            $ResID = get-azresource -Name $name
            $RID = $ResID.ResourceId
            $SQLRID = $RID | Where-Object { $_ -match "Microsoft.AzureArcData/SqlServerInstances" }       
            "$name,$major_version,$SQLRID"
        }
    }
}
