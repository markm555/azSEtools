
<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                            Author & License Information                                             ****
****                                                                                                                     ****
****  Author:        Mark Moore                                                                                          ****
****  GitHub:        https://github.com/markm555                                                                         ****
****                                                                                                                     ****
****  Version History:                                                                                                   ****
****      v1.0.0  - Initial creation                                                                                     ****
****                                                                                                                     ****
****  License: MIT License                                                                                               ****
****                                                                                                                     ****
****  Copyright (c) 2026 Mark Moore                                                                                      ****
****                                                                                                                     ****
****  Permission is hereby granted, free of charge, to any person obtaining a copy                                       ****
****  of this software and associated documentation files (the "Software"), to deal                                      ****
****  in the Software without restriction, including without limitation the rights                                       ****
****  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell                                          ****
****  copies of the Software, and to permit persons to whom the Software is                                              ****
****  furnished to do so, subject to the following conditions:                                                           ****
****                                                                                                                     ****
****  The above copyright notice and this permission notice shall be included in                                         ****
****  all copies or substantial portions of the Software.                                                                ****
****                                                                                                                     ****
****  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR                                         ****
****  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,                                           ****
****  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE                                        ****
****  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER                                             ****
****  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,                                      ****
****  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN                                          ****
****  THE SOFTWARE.                                                                                                      ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>

<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                   Service Principal (SPN) & Purview Configuration                                   ****
****                                                                                                                     ****
****  A Service Principal (SPN) represents an application identity in Microsoft Entra ID (Azure AD).                     ****
****  It is used for non-interactive authentication scenarios, such as automation, background jobs, and                  ****
****  service-to-service API calls.                                                                                      ****
****                                                                                                                     ****
****  In this script, the SPN is used to authenticate to Microsoft Entra ID and request an access token,                 ****
****  which is then passed to Microsoft Purview REST APIs to authorize data access.                                      ****
****                                                                                                                     ****
****  IMPORTANT: The client secret is hard-coded in this script for demonstration and sample purposes only.              ****
****  In production scenarios, secrets must never be stored in source code.                                              ****
****  Instead, secrets should be stored securely using a service such as Azure Key Vault,                                ****
****  and retrieved at runtime using managed identity, environment variables, or secure configuration stores.            ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>

<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                 Required Permissions for Microsoft Purview APIs                                     ****
****                                                                                                                     ****
****  Access to Microsoft Purview Data Map APIs requires permissions to be granted                                       ****
****  across multiple authorization layers. Administrative roles alone are not                                           ****
****  sufficient to access catalog metadata, asset search, or lineage information.                                       ****
****                                                                                                                     ****
****  The Service Principal (SPN) used by this script must be granted permissions                                        ****
****  at BOTH the Azure resource level AND within the Microsoft Purview Data Map.                                        ****
****                                                                                                                     ****
****  1) Azure Portal (Control Plane Permissions):                                                                       ****
****     The SPN must be assigned at least the Reader role on the Microsoft Purview                                      ****
****     account resource in the Azure Portal. This allows the identity to be recognized                                 ****
****     by the Purview service itself.                                                                                  ****
****                                                                                                                     ****
****     Azure Portal → Microsoft Purview account → Access Control (IAM)                                                 ****
****         Role  : Reader                                                                                              ****
****         Scope : Purview account resource                                                                            ****
****                                                                                                                     ****
****  2) Microsoft Purview Studio (Data Plane Permissions):                                                              ****
****     The SPN must be explicitly assigned Data Map permissions within Purview                                         ****
****     Studio at the Domain or Collection scope where the assets reside.                                               ****
****                                                                                                                     ****
****     Purview Studio → Data Map → Domains → <Domain Name> → Role assignments                                          ****
****         Minimum Role Required : Purview Data Reader                                                                 ****
****                                                                                                                     ****
****     NOTE: Administrative roles such as Domain Admin, Collection Admin, or                                           ****
****     Purview Administrator do NOT automatically grant permission to read                                             ****
****     catalog assets via the Data Map APIs. The Purview Data Reader role                                              ****
****     is explicitly required for API-based search, entity enumeration, and                                            ****
****     lineage retrieval.                                                                                              ****
****                                                                                                                     ****
****  3) Collection Scope Matters:                                                                                       ****
****     If assets are stored in child collections, the SPN must have permission                                         ****
****     at that collection level, or inheritance must be enabled from the parent                                        ****
****     domain. Missing collection access will result in HTTP 403 "Not authorized                                       ****
****     to access account" errors even when tokens are valid.                                                           ****
****                                                                                                                     ****
****  4) Token Behavior:                                                                                                 ****
****     Permissions are evaluated when an access token is issued. After changing                                        ****
****     role assignments, allow time for propagation and request a NEW access                                           ****
****     token before retrying API calls.                                                                                ****
****                                                                                                                     ****
****  Summary:                                                                                                           ****
****     - Azure IAM Reader        → Identifies the SPN to the Purview service                                           ****
****     - Purview Data Reader     → Authorizes catalog and lineage API access                                           ****
****     - Admin roles alone       → Not sufficient for Data Map API calls                                               ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>

# -------------------------------
# REQUIRED SETTINGS (EDIT THESE)
# -------------------------------
$TenantId     = "<Tenant_ID>"
$ClientId     = "<Client_ID>"
$ClientSecret = "<Client_Secret>"

$PurviewName  = "<Your Purview Name>"     # e.g. "markm-purview"
$PurviewResource = "https://purview.azure.net"

<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                               Get Access Token                                                      ****
****  The access token is issued by Microsoft Entra ID (Azure AD) and is used to authenticate all subsequent API calls.  ****
****  It represents the identity and permissions of the calling application and is passed as a Bearer token in           ****
****  the Authorization header when invoking Microsoft Purview REST APIs.                                                ****
****                                                                                                                     ****
****  Access tokens are time-bound; by default, an access token has a lifetime (TTL) of approximately 1 hour.            ****
****  After expiration, a new token must be requested to continue accessing protected resources.                         ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>
function Get-PurviewAccessToken {
    param (
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret
    )

    # Ensure TLS 1.2 for Entra ID endpoints (good practice in Windows PowerShell 5.1)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $uri  = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "$PurviewResource/.default"
        grant_type    = "client_credentials"
    }

    try {
        $tokenResponse = Invoke-RestMethod `
            -Method Post `
            -Uri $uri `
            -ContentType "application/x-www-form-urlencoded" `
            -Body $body `
            -TimeoutSec 30 `
            -ErrorAction Stop

        return $tokenResponse.access_token
    }
    catch {
        Write-Error ("Token request failed: " + $_.Exception.Message)

        if ($_.Exception.Response -and $_.Exception.Response.GetResponseStream()) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $respBody = $reader.ReadToEnd()
            if ($respBody) { Write-Error ("Response body: " + $respBody) }
        }
        throw
    }
}

<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                         Invoke Purview REST API Function                                            ****
****                                                                                                                     ****
****  This function provides a reusable and centralized way to invoke Microsoft Purview Data Map (Atlas) REST APIs.      ****
****  It builds the full URL using the Purview account name and a relative path (ex: datamap/api/atlas/v2/types/typedefs)****
****  and sends the request with the Authorization Bearer token.                                                         ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>
function Invoke-PurviewApi {
    param(
        [Parameter(Mandatory)][string]$PurviewAccountName,
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][ValidateSet("GET","POST")][string]$Method,
        [Parameter(Mandatory)][string]$RelativePath,   # e.g. "datamap/api/atlas/v2/types/typedefs"
        [object]$Body = $null
    )

    $baseUrl = "https://$PurviewAccountName.purview.azure.com"
    $url = "$baseUrl/$RelativePath"

    $headers = @{
        "Accept"        = "application/json"
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    try {
        if ($Method -eq "POST") {
            $jsonBody = $null
            if ($Body) { $jsonBody = ($Body | ConvertTo-Json -Depth 30) }

            return Invoke-RestMethod `
                -Method Post `
                -Uri $url `
                -Headers $headers `
                -Body $jsonBody `
                -TimeoutSec 60 `
                -ErrorAction Stop
        }
        else {
            return Invoke-RestMethod `
                -Method Get `
                -Uri $url `
                -Headers $headers `
                -TimeoutSec 60 `
                -ErrorAction Stop
        }
    }
    catch {
        # Emit useful diagnostics for 401/403/404
        Write-Error ("Purview API call failed: " + $_.Exception.Message)
        if ($_.Exception.Response) {
            try {
                $statusCode = [int]$_.Exception.Response.StatusCode
                Write-Error ("HTTP Status Code: " + $statusCode)
            } catch {}

            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $respBody = $reader.ReadToEnd()
                if ($respBody) { Write-Error ("Response body: " + $respBody) }
            } catch {}
        }
        throw
    }
}

# -------------------------------
# MAIN EXECUTION
# -------------------------------
$token = Get-PurviewAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

# Optional sanity check
# $token | Measure-Object

<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                        Get Types and Type Definitions                                               ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>

# Get all type definitions (Atlas type system). This is commonly used to discover concrete asset types that inherit DataSet. 
$typedefs = Invoke-PurviewApi `
    -PurviewAccountName $PurviewName `
    -AccessToken $token `
    -Method GET `
    -RelativePath "datamap/api/atlas/v2/types/typedefs"

# $typedefs | ConvertTo-Json -Depth 50

# Identify concrete DataSet-derived types (avoid querying the base type "DataSet" directly).
$dataSetTypes = @()
if ($typedefs -and $typedefs.entityDefs) {
    $dataSetTypes = $typedefs.entityDefs |
        Where-Object { $_.superTypes -contains "DataSet" -and $_.name -ne "DataSet" } |
        Select-Object -ExpandProperty name
}

Write-Host "Found $($dataSetTypes.Count) DataSet-derived types."

<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                           Search Assets (Example: Tables)                                           ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>

# Pick a concrete type you expect to exist. "azure_sql_table" is a common one; adjust to your environment.
# Search is performed via the Data Map Atlas endpoint (NOT catalog/api). 
$assetTypeToSearch = "azure_sql_table"

$respt = Invoke-PurviewApi `
    -PurviewAccountName $PurviewName `
    -AccessToken $token `
    -Method POST `
    -RelativePath "datamap/api/atlas/v2/search/basic" `
    -Body @{
        typeName = $assetTypeToSearch
        limit    = 1000
    }

# Output minimal view
$respt.entities | Select-Object guid, typeName, displayText

<#
*****************************************************************************************************************************
****                                                                                                                     ****
****                                               Get Purview Lineage                                                   ****
****                                                                                                                     ****
*****************************************************************************************************************************
#>

# Loop assets returned from search/basic and request lineage by GUID.
$lineageResults = @()

foreach ($asset in $respt.entities) {
    $AssetGuid = $asset.guid

    $lineage = Invoke-PurviewApi `
        -PurviewAccountName $PurviewName `
        -AccessToken $token `
        -Method GET `
        -RelativePath "datamap/api/atlas/v2/lineage/$AssetGuid?direction=BOTH&depth=5"

    $lineageResults += $lineage
}

# Convert lineage results to JSON for export/reporting
$lineageResults | ConvertTo-Json -Depth 50
``
