param (
    [string]$Filetype = "csv",
    [int]$Days = -7, # Number of days to go back, 0 is today, -1 is yesterday, etc.
    [int]$Day = 0,
    [string] $filter = "",
    [string]$Filepreface = "",
    [string]$StorageAccount = "markmout", # Just what you named it, I will append the rest of the url to it.
    [string]$StorageContainer = "activityevents" # The name of the container you created in Azure Storage
)
$type = $filetype.ToLower()
if ($Days -lt 0)
{}
else
{
    $Days = $Days * -1
}

#****************************************************************
#                  Begin Function Definitions                   *
#****************************************************************
function Get-DateTimeRange {
param(
    [int]$DateOffset     # negative number added to today
)
$today = Get-Date
$calculatedDate = $today.AddDays($DateOffset)

$result = @{
    Date = $calculatedDate.ToString("yyyy-MM-dd")
    StartDateTime = $calculatedDate.ToString("yyyy-MM-ddT00:00:00")
    EndDateTime = $calculatedDate.ToString("yyyy-MM-ddT23:59:59")
}

return $result
}

function Get-BlobToken {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
        resource      = "https://storage.azure.com/"
    }

    $url = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $response = Invoke-RestMethod -Method Post -Uri $url -ContentType "application/x-www-form-urlencoded" -Body $body
    return $response.access_token
}
function Get-AccessToken {
param (
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$TenantId
)

$body = @{
        client_id     = $ClientId
        scope         = "https://analysis.windows.net/powerbi/api/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    $url = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $response = Invoke-RestMethod -Method Post -Uri $url -ContentType "application/x-www-form-urlencoded" -Body $body
    $response
    return $response.access_token
}

function Get-ActivityEvents{
param (
    [string]$AccessToken,
    [string]$StartDateTime,
    [string]$EndDateTime,
    [string]$Filter
)
try {
$baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/activityevents"
$activityEventEntities = @()
$continuationToken = $null

$header = @{
      "Authorization" = "Bearer $AccessToken"
      "Content-Type"  = "application/json"
  }
do {
    if ($continuationToken) {
       $activityEventsUrl = $baseUrl + "?continuationToken='$continuationToken'"
    } else {
        $activityEventsUrl = $baseUrl + "?startDateTime='$StartDateTime'&endDateTime='$EndDateTime'"

    }
        if (!([string]::IsNullOrEmpty($Filter))) {
            $activityEventsUrl += "&`$filter=$Filter"
        }
        Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $result = Invoke-RestMethod -Method Get -Uri $activityEventsUrl -Headers $header
        $activityEventEntities += $result.activityEventEntities
        $continuationToken = $result.continuationToken
        return $activityEventEntities 
    } while ($continuationToken)
    } catch {
        Write-Error "Error getting activity events: $($_.Exception.Message)"
        Write-Error $_.ErrorDetails
        throw
    }
}

#****************************************************************
#*                    End Function Definitions                  *
#****************************************************************

$StorageAccount = "markmout"  # Just what you named it, I will append the rest of the url to it.
$StorageContainer = "activityevents"
$blobUri = "https://" + $StorageAccount + ".blob.core.windows.net/" + $StorageContainer + "/" + ($Date.StartDateTime -replace "[:\\/]", "-") + ".csv"
$Date = Get-DateTimeRange($Day)
#$Date.StartDateTime
#$Date.EndDateTime

$filetype = "CSV"

# If in Azure Automation pull stored credentials if interactive hard coded credentials
$ClientID = $Credential.Username
$ClientSecret = $Credential.Password#>
if ($env:AZUREPS_HOST_ENVIRONMENT -like "*AzureAutomation*") 
{
    $TenantId = "<Your Tenant ID"
    $Credential = Get-AutomationPSCredential -Name "FabricAdmin"
    $ClientID = $Credential.Username
    $SecureSecret = $Credential.Password
    $ClientSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureSecret)) 


}
else
{
    $TenantId = "<Your Tenant ID>"
    $ClientId = "<Your Client ID>"
    $ClientSecret = "<Your Client Tenant>"
}

#****************************************************************
#*                        Execution Code                        *
#*              Modify Code here with your values               *
#****************************************************************

$AccessToken = Get-AccessToken -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId  #  Get Access Token for API calls.  One for the Fabric API 
$token = Get-BlobToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret          #  and one for the Blob API since they have different scopes

$ClientSecret = $null

while ($Day -ge $Days){

    $Date = Get-DateTimeRange($Day)
    $ActivityEvents = Get-ActivityEvents -AccessToken $AccessToken.access_token -StartDateTime $Date.StartDateTime -EndDateTime $Date.EndDateTime -Filter $filter

    $flattendEvents = $ActivityEvents | Select-Object -Property * | ForEach-Object {
      [PSCustomObject]@{
          Id = $_.Id
          RecordType = $_.RecordType
          CreationTime = $_.CreationTime
          Operation = $_.Operation
          OrganizationId = $_.OrganizationId
          UserType = $_.UserType
          UserKey = $_.UserKey
          Workload = $_.Workload
          UserId = $_.UserId
          ClientIP = $_.ClientIP
          Activity = $_.Activity
          ItemName = $_.ItemName
          WorkSpaceName = $_.WorkSpaceName
          DataSetName = $_.DatasentName
          ReportName = $_.ReportName
          CapacityId = $_.CapacityId
          CapacityName =$_.CapacityName
          WorkspaceId = $_.WorkspaceId
          ObjectId = $_.ObjectId
          DatasetId = $_.DatasetId
          ReportId = $_.ReportId
          EmbedTokenId = $_.EmbedTokenId
          ArtifactId = $_.ArtifactId
          ArtifactName = $_.ArtifactName
          IsSuccess = $_.IsSuccess
          ReportType = $_.ReportType
          RequestId = $_.RequestId
          ActivityId = $_.ActivityId
          DistributionMethod = $_.DistributionMethod
          ConsumptionMethod = $_.ConsumptionMethod
          ArtifactKind = $_.ArtifactKind
          RefreshEnforcementPolicy = $_.RefreshEnforcementPolicy
          BillingType = $_.BillingType
          # Add more properties as needed
        } 
    }
            if($type -eq "csv")
            {
                $String = $flattendEvents | ConvertTo-Csv -NoTypeInformation -Delimiter ","
                $blobUri = "https://" + $StorageAccount + ".blob.core.windows.net/" + $StorageContainer + "/" + $Filepreface + ($Date.StartDateTime -replace "[:\\/]", "-") + ".csv"
                $Data = $flattendEvents | ConvertTo-Csv -NoTypeInformation
            }
            elseif($type -eq "json")
            {
                $String = $flattendEvents | ConvertTo-Json
                $blobUri = "https://" + $StorageAccount + ".blob.core.windows.net/" + $StorageContainer + "/" + $Filepreface + ($Date.StartDateTime -replace "[:\\/]", "-") + ".json"
                $Data = $flattendEvents | ConvertTo-Json
            }
            else
            {
                write-output "$type - File type not supported"
                break
            }

            #$Data = $flattendEvents | ConvertTo-Json #-NoTypeInformation
            $String = $Data -join "`r`n"

            # Convert CSV string to a byte array
            $byteArray = [System.Text.Encoding]::UTF8.GetBytes($String)
           
            # Set the headers for the API call
            $headers = @{
                "x-ms-blob-type" = "BlockBlob"
                "Authorization" = "Bearer $token"
                "x-ms-version" = "2020-10-02"
                "Content-Type" = "application/octet-stream"
            }
            
            # Make the API call to upload the blob
            $response = Invoke-RestMethod -Uri $blobUri -Method Put -Headers $headers -Body $String 
            $Day = $Day - 1
 }  
