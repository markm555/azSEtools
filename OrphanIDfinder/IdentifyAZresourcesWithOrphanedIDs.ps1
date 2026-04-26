#Requires -Modules Az.Accounts, Az.Resources, Az.ResourceGraph

<#
.SYNOPSIS
  Enumerate Azure Resource Groups + Resources and all RBAC role assignments,
  and identify likely orphaned/unresolved principals ("Unknown"/missing name/"identity not found").

.DESCRIPTION
  - Iterates all subscriptions you can access
  - Gets role assignments at subscription scope, RG scope, and resource scope
  - Joins with resource inventory (Resource Graph) for scalable enumeration
  - Flags suspicious/orphaned assignments:
      * ObjectType == 'Unknown'
      * DisplayName empty/null
      * SignInName empty/null AND principal looks unresolved
  - Exports full and orphan-only CSVs

.NOTES
  Requires Az modules and permission to read role assignments (e.g., Reader at scope + Microsoft.Authorization/roleAssignments/read).
  "Identity not found" conditions can occur when Entra principals are deleted but RBAC remains. [1](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments)

.LICENSE
    MIT License

    Copyright (c) 2026 Mark Moore

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the “Software”), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

.VERSION
    1.0

.NOTES
    GitHub: https://github.com/markm555
    Use for auditing and cleanup of orphaned RBAC assignments.
#>

[CmdletBinding()]
param(
  [switch]$AllSubscriptions = $true,
  [string[]]$SubscriptionId,
  [string]$OutputFolder = ".",
  [int]$ResourceGraphPageSize = 1000
)

$ErrorActionPreference = "Stop"

# Connect (interactive). If you prefer device code:
# Connect-AzAccount -UseDeviceAuthentication
#Connect-AzAccount | Out-Null

# Determine subscriptions
$subs =
if ($AllSubscriptions -or -not $SubscriptionId) {
  Get-AzSubscription
} else {
  Get-AzSubscription | Where-Object { $_.Id -in $SubscriptionId }
}

if (-not $subs) {
  throw "No subscriptions found (or you don't have access)."
}

# Helper: robust orphan detection
function Test-IsOrphanedRoleAssignment {
  param([Parameter(Mandatory)]$ra)

  # Heuristics based on common unresolved patterns [2](https://Supportability.visualstudio.com/BizAppsSupportability/_wiki/wikis/BizAppsSupportability.wiki/2370297)[1](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments)
  $unknownType = ($ra.ObjectType -eq "Unknown")
  $noDisplay   = [string]::IsNullOrWhiteSpace($ra.DisplayName)
  $noSignin    = [string]::IsNullOrWhiteSpace($ra.SignInName)

  # If ObjectType is Unknown OR no DisplayName, it's suspicious.
  if ($unknownType -or $noDisplay) { return $true }

  # If it looks like a user assignment but lacks sign-in name, also suspicious.
  if (($ra.ObjectType -eq "User") -and $noSignin) { return $true }

  return $false
}

# Output collections
$all = New-Object System.Collections.Generic.List[object]
$orphans = New-Object System.Collections.Generic.List[object]

# Ensure output folder
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

foreach ($sub in $subs) {
  Write-Host "`n==== Subscription: $($sub.Name) ($($sub.Id)) ====" -ForegroundColor Cyan
  Set-AzContext -SubscriptionId $sub.Id | Out-Null

  # 1) Inventory resources via Resource Graph (fast + scalable)
  # Returns id, name, type, resourceGroup, location
  $rgQuery = @"
resourcecontainers
| where type == 'microsoft.resources/subscriptions/resourcegroups'
| project subscriptionId, resourceGroup = name, location
"@

  $resQuery = @"
resources
| project id, name, type, resourceGroup, location
"@

  $rgs = @()
  $resources = @()

  $rgs = Search-AzGraph -Query $rgQuery -First $ResourceGraphPageSize
  $resources = Search-AzGraph -Query $resQuery -First $ResourceGraphPageSize

  # 2) Role assignments at subscription scope
  $subScope = "/subscriptions/$($sub.Id)"
  Write-Host "Getting role assignments at subscription scope..." -ForegroundColor Gray
  $subRas = Get-AzRoleAssignment -Scope $subScope -IncludeClassicAdministrators -ErrorAction SilentlyContinue

  foreach ($ra in $subRas) {
    $row = [pscustomobject]@{
      SubscriptionName   = $sub.Name
      SubscriptionId     = $sub.Id
      ScopeLevel         = "Subscription"
      Scope              = $ra.Scope
      RoleDefinitionName = $ra.RoleDefinitionName
      ObjectId           = $ra.ObjectId
      ObjectType         = $ra.ObjectType
      DisplayName        = $ra.DisplayName
      SignInName         = $ra.SignInName
      RoleAssignmentId   = $ra.RoleAssignmentId
      ResourceGroup      = $null
      ResourceId         = $null
      ResourceType       = $null
      ResourceName       = $null
    }

    $all.Add($row) | Out-Null
    if (Test-IsOrphanedRoleAssignment -ra $ra) { $orphans.Add($row) | Out-Null }
  }

  # 3) Role assignments at resource group scope
  Write-Host "Getting role assignments at resource group scope..." -ForegroundColor Gray
  foreach ($rg in $rgs) {
    $rgName = $rg.resourceGroup
    $rgScope = "/subscriptions/$($sub.Id)/resourceGroups/$rgName"

    $rgRas = Get-AzRoleAssignment -Scope $rgScope -ErrorAction SilentlyContinue
    foreach ($ra in $rgRas) {
      $row = [pscustomobject]@{
        SubscriptionName   = $sub.Name
        SubscriptionId     = $sub.Id
        ScopeLevel         = "ResourceGroup"
        Scope              = $ra.Scope
        RoleDefinitionName = $ra.RoleDefinitionName
        ObjectId           = $ra.ObjectId
        ObjectType         = $ra.ObjectType
        DisplayName        = $ra.DisplayName
        SignInName         = $ra.SignInName
        RoleAssignmentId   = $ra.RoleAssignmentId
        ResourceGroup      = $rgName
        ResourceId         = $null
        ResourceType       = $null
        ResourceName       = $null
      }

      $all.Add($row) | Out-Null
      if (Test-IsOrphanedRoleAssignment -ra $ra) { $orphans.Add($row) | Out-Null }
    }
  }

  # 4) Role assignments at resource scope (can be a lot!)
  Write-Host "Getting role assignments at resource scope (this can be slow in large subs)..." -ForegroundColor Gray
  foreach ($res in $resources) {
    $resId = $res.id
    $resRas = Get-AzRoleAssignment -Scope $resId -ErrorAction SilentlyContinue

    foreach ($ra in $resRas) {
      $row = [pscustomobject]@{
        SubscriptionName   = $sub.Name
        SubscriptionId     = $sub.Id
        ScopeLevel         = "Resource"
        Scope              = $ra.Scope
        RoleDefinitionName = $ra.RoleDefinitionName
        ObjectId           = $ra.ObjectId
        ObjectType         = $ra.ObjectType
        DisplayName        = $ra.DisplayName
        SignInName         = $ra.SignInName
        RoleAssignmentId   = $ra.RoleAssignmentId
        ResourceGroup      = $res.resourceGroup
        ResourceId         = $resId
        ResourceType       = $res.type
        ResourceName       = $res.name
      }

      $all.Add($row) | Out-Null
      if (Test-IsOrphanedRoleAssignment -ra $ra) { $orphans.Add($row) | Out-Null }
    }
  }
}

# Export
$allPath     = Join-Path $OutputFolder "rbac-all-assignments.csv"
$orphPath    = Join-Path $OutputFolder "rbac-orphaned-assignments.csv"

$all     | Sort-Object SubscriptionName, ScopeLevel, Scope, RoleDefinitionName, DisplayName |
  Export-Csv -Path $allPath -NoTypeInformation

$orphans | Sort-Object SubscriptionName, ScopeLevel, Scope, RoleDefinitionName, DisplayName |
  Export-Csv -Path $orphPath -NoTypeInformation

Write-Host "`nDONE." -ForegroundColor Green
Write-Host "All assignments:     $allPath"
Write-Host "Orphaned candidates: $orphPath"
Write-Host "Tip: Orphans often show as ObjectType 'Unknown' / missing DisplayName / 'Identity not found' scenarios. [1](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments)[2](https://Supportability.visualstudio.com/BizAppsSupportability/_wiki/wikis/BizAppsSupportability.wiki/2370297)"
