Import-Module Az.Storage

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
          Write-Output "Getting activity events from $($activityEventsUrl)"

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
    $ClientId = "<Your Client ID Here>"
    $ClientSecret = "<Your Client Secret Here>"
    $TenantId = "<Your Tenant ID Here>"

    $days = 0
    $day = -21

    $StorageAccount = "<Your Storage Account Here>"  # Just what you named it, I will append the rest of the url to it.
    $StorageContainer = "<Your Contianer Here>"

#****************************************************************
#*                        Execution Code                        *
#*              Modify Code here with your values               *
#****************************************************************

  
    $AccessToken = Get-AccessToken -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId
    $BlobToken = Get-BlobToken -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId


    $credential = [Azure.Identity.ClientSecretCredential]::new($tenantId, $clientId, $clientSecret)


    #Write-Output $AccessToken

    while ($day -le $days) {
        $Date = Get-DateTimeRange($day)
        $Date.StartDateTime
        $Date.EndDateTime

        $type = "Activity eq 'viewreport'"
    
        $ActivityEvents = Get-ActivityEvents -AccessToken $AccessToken.access_token -StartDateTime $Date.StartDateTime -EndDateTime $Date.EndDateTime -Filter $type
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


                # Write data to Blob Storage
                # Construct the Blob URI

                $blobUri = "https://" + $StorageAccount + ".blob.core.windows.net/" + $StorageContainer + "/" + ($Date.StartDateTime -replace "[:\\/]", "-") + ".csv"

                # Initialize the BlobClient
                $blobClient = [Azure.Storage.Blobs.BlobClient]::new([System.Uri]$blobUri, $credential)
                # Create a BlobContainerClient

                #$BlobClient = [Azure.Storage.Blobs.BlobContainerClient]::new([System.Uri]$blobUri, $credential)

                # Convert structured data to a CSV string
                $csvData = $flattendEvents | ConvertTo-Csv -NoTypeInformation
                $csvString = $csvData -join "`r`n"

                # Convert CSV string to a byte array
                $byteArray = [System.Text.Encoding]::UTF8.GetBytes($csvString)

                # Create a stream from the byte array
                $stream = [System.IO.MemoryStream]::new($byteArray)

                # Debugging outputs
                Write-Output "Blob URI: $blobUri"
                Write-Output "Date: $Date.StartDateTime"
                Write-Output "Stream length: $($stream.Length)"

                # Upload to Blob Storage
                try {
                    $blobClient.Upload($stream, $true)  # Overwrite if exists
                    Write-Output "File uploaded successfully using RBAC!"
                } catch {
                    Write-Error "Upload failed: $($_.Exception.Message)"
                    Write-Error "Inner Exception: $($_.Exception.InnerException.Message)"
                }
                    $day = $day+1
     }  
