#Write a memory stream of data to an Azure Blob Storage account using the REST API and a JSON Web Token (JWT) for authentication.

# Pull a Jason Web Token to be used to access azure Blob Storage
$storageAccountName = "markmout"
$containerName = "activityevents"
$blobName = "Text.csv"
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
$TenantId = "<Your Tenant>"
$ClientId = "<Your Client ID>"
$ClientSecret = "<Your Client Secret>"

# call the Get-BlobToken function to get the token
$token = Get-BlobToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

# Create a memory stream and write some data into it
$memoryStream = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.StreamWriter($memoryStream)
$writer.Write("Hello, Azure Blob Storage.  I can't believe you finally worked.  Thank God!")
$writer.Flush()
$memoryStream.Position = 0

# Define the API endpoint for uploading the blob
$apiUrl = "https://$storageAccountName.blob.core.windows.net/$containerName/$blobName"

# Set the headers for the API call
$headers = @{
    "x-ms-blob-type" = "BlockBlob"
    "Authorization" = "Bearer $token"
    "x-ms-version" = "2020-10-02"
    "Content-Type" = "application/octet-stream"
    "Content-Length" = $memoryStream.Length
}

# Make the API call to upload the blob
$response = Invoke-RestMethod -Uri $apiUrl -Method Put -Headers $headers -Body $memoryStream.ToArray()

Write-Host "Data successfully uploaded to Azure Blob Storage via API."


