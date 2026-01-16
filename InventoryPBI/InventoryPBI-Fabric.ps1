# -------------------------------
# Connect to Power BI (Admin APIs)
# -------------------------------
Connect-PowerBIServiceAccount

# Collect results
$inventory = @()

# --- Power BI Admin APIs ---
# Datasets
$datasets = Invoke-PowerBIRestMethod -Url "/admin/datasets" -Method Get | ConvertFrom-Json
foreach ($ds in $datasets.value) {
    $inventory += [pscustomobject]@{
        Workspace = $ds.workspaceId
        AssetType = "Dataset"
        Name      = $ds.name
        Id        = $ds.id
        Owner     = $ds.createdBy
    }
}

# Reports
$reports = Invoke-PowerBIRestMethod -Url "/admin/reports" -Method Get | ConvertFrom-Json
foreach ($r in $reports.value) {
    $inventory += [pscustomobject]@{
        Workspace = $r.workspaceId
        AssetType = "Report"
        Name      = $r.name
        Id        = $r.id
        Owner     = $r.createdBy
    }
}

# Dashboards
$dashboards = Invoke-PowerBIRestMethod -Url "/admin/dashboards" -Method Get | ConvertFrom-Json
foreach ($d in $dashboards.value) {
    $inventory += [pscustomobject]@{
        Workspace = $d.workspaceId
        AssetType = "Dashboard"
        Name      = $d.displayName
        Id        = $d.id
        Owner     = $d.createdBy
    }
}

# Dataflows
$dataflows = Invoke-PowerBIRestMethod -Url "/admin/dataflows" -Method Get | ConvertFrom-Json
foreach ($df in $dataflows.value) {
    $inventory += [pscustomobject]@{
        Workspace = $df.workspaceId
        AssetType = "Dataflow"
        Name      = $df.name
        Id        = $df.id
        Owner     = $df.createdBy
    }
}

# -------------------------------
# Fabric REST API (lakehouses, etc.)
# -------------------------------

# Acquire Fabric token (client credentials flow)
$tenantId = "<tenant-id>"
$clientId = "<app-id>"
$clientSecret = "<secret>"

$body = @{
    grant_type    = "client_credentials"
    scope         = "https://api.fabric.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
$fabricToken = $tokenResponse.access_token
$fabricHeaders = @{ Authorization = "Bearer $fabricToken" }

# Get all workspaces (from Power BI API)
$workspaces = Get-PowerBIWorkspace -Scope Organization -All

foreach ($ws in $workspaces) {
    $wsId = $ws.Id

    # Lakehouses
    try {
        $lakehouses = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/lakehouses" -Headers $fabricHeaders -Method Get
        foreach ($lh in $lakehouses.value) {
            $inventory += [pscustomobject]@{
                Workspace = $ws.Name
                AssetType = "Lakehouse"
                Name      = $lh.displayName
                Id        = $lh.id
                Owner     = $lh.properties.owner
            }
        }
    } catch {}

    # Warehouses
    try {
        $warehouses = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/datawarehouses" -Headers $fabricHeaders -Method Get
        foreach ($wh in $warehouses.value) {
            $inventory += [pscustomobject]@{
                Workspace = $ws.Name
                AssetType = "Warehouse"
                Name      = $wh.displayName
                Id        = $wh.id
                Owner     = $wh.properties.owner
            }
        }
    } catch {}

    # Notebooks
    try {
        $notebooks = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/notebooks" -Headers $fabricHeaders -Method Get
        foreach ($nb in $notebooks.value) {
            $inventory += [pscustomobject]@{
                Workspace = $ws.Name
                AssetType = "Notebook"
                Name      = $nb.displayName
                Id        = $nb.id
                Owner     = $nb.properties.owner
            }
        }
    } catch {}

    # Pipelines
    try {
        $pipelines = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$wsId/pipelines" -Headers $fabricHeaders -Method Get
        foreach ($pl in $pipelines.value) {
            $inventory += [pscustomobject]@{
                Workspace = $ws.Name
                AssetType = "Pipeline"
                Name      = $pl.displayName
                Id        = $pl.id
                Owner     = $pl.properties.owner
            }
        }
    } catch {}
}

# -------------------------------
# Export unified inventory
# -------------------------------
$inventory | Format-Table -AutoSize
$inventory | Export-Csv -Path ".\Fabric_PowerBI_Inventory.csv" -NoTypeInformation
