<#
.SYNOPSIS
Bulk uploads blocked domains into a Microsoft Entra B2B Management Policy using Microsoft Graph (beta).

.DESCRIPTION
- Retrieves/uses a B2B Management Policy ID
- Loads domains from CSV (column: domain) or TXT (one per line)
- Builds the policy definition JSON and patches the policy via Microsoft Graph
- Performs a critical request size check (25,000 character limit)

.REQUIREMENTS
- Microsoft Graph PowerShell SDK
- Graph profile: beta
- Permission: Policy.ReadWrite.B2BManagementPolicy

.EXAMPLE
.\Update-B2BBlockedDomainsPolicy.ps1 -PolicyId "<policy-guid>" -Path ".\sample-data\blocked-domains.sample.csv"

.EXAMPLE
.\Update-B2BBlockedDomainsPolicy.ps1 -PolicyId "<policy-guid>" -Path ".\sample-data\blocked-domains.sample.txt"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PolicyId,

    [Parameter(Mandatory = $true)]
    [string]$Path
)

Write-Host "== Microsoft Entra B2B Blocked Domains Uploader ==" -ForegroundColor Cyan

# -----------------------------
# CONNECT
# -----------------------------
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes "Policy.ReadWrite.B2BManagementPolicy" | Out-Null
Select-MgProfile beta

# -----------------------------
# LOAD DOMAINS (CSV or TXT)
# -----------------------------
if (-not (Test-Path $Path)) {
    throw "Input file not found: $Path"
}

$ext = [System.IO.Path]::GetExtension($Path).ToLower()

switch ($ext) {
    ".csv" {
        $domains = Import-Csv $Path |
            ForEach-Object { $_.domain.Trim().ToLower() } |
            Where-Object { $_ -and $_.Contains('.') } |
            Sort-Object -Unique
    }
    ".txt" {
        $domains = Get-Content $Path |
            ForEach-Object { $_.Trim().ToLower() } |
            Where-Object { $_ -and $_.Contains('.') } |
            Sort-Object -Unique
    }
    default {
        throw "Unsupported file type: $ext. Please use .csv or .txt"
    }
}

Write-Host "Total domains loaded: $($domains.Count)" -ForegroundColor Green

# -----------------------------
# BUILD DEFINITION (STRING JSON)
# -----------------------------
$innerPolicy = @{
    B2BManagementPolicy = @{
        InvitationsAllowedAndBlockedDomainsPolicy = @{
            BlockedDomains = $domains
        }
        AutoRedeemPolicy = @{
            AdminConsentedForUsersIntoTenantIds = @()
            NoAADConsentForUsersFromTenantsIds  = @()
        }
    }
} | ConvertTo-Json -Compress -Depth 20

$body = @{
    definition = @($innerPolicy)
} | ConvertTo-Json -Compress -Depth 20

# -----------------------------
# SIZE CHECK (CRITICAL)
# -----------------------------
$charCount = $body.Length
Write-Host "Policy JSON size (characters): $charCount" -ForegroundColor Yellow

if ($charCount -gt 25000) {
    Write-Warning "❌ Policy exceeds 25,000 character limit. Graph call will fail."
    Write-Warning "❌ Recommendation: Reduce domain count, split strategy, or consider allow-list approach."
    return
}

# -----------------------------
# PATCH POLICY
# -----------------------------
$uri = "https://graph.microsoft.com/beta/policies/b2bManagementPolicies/$PolicyId"

Write-Host "Updating policy: $PolicyId" -ForegroundColor Yellow

Invoke-MgGraphRequest `
    -Method PATCH `
    -Uri $uri `
    -Body $body `
    -ContentType "application/json"

Write-Host "✅ Policy updated successfully" -ForegroundColor Green
