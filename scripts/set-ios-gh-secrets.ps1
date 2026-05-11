param(
    [string]$Repo = "tkolya-dotcom/Korneo"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Set-Secret {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Host "Skip empty secret: $Name" -ForegroundColor Yellow
        return
    }

    $Value | gh secret set $Name --repo $Repo
    Write-Host "Updated secret: $Name" -ForegroundColor Green
}

Write-Host "Configuring iOS signing secrets for $Repo" -ForegroundColor Cyan
Write-Host "Apple Developer Program subscription is required for device IPA install." -ForegroundColor Cyan

$teamId = Read-Host "APPLE_TEAM_ID (Team ID)"
$bundleId = Read-Host "APPLE_BUNDLE_ID (default: com.korneo.ios)"
if ([string]::IsNullOrWhiteSpace($bundleId)) {
    $bundleId = "com.korneo.ios"
}
$apiKeyId = Read-Host "APPLE_API_KEY_ID (Key ID)"
$issuerId = Read-Host "APPLE_API_ISSUER_ID (Issuer ID)"
$p8Path = Read-Host "Path to AuthKey_XXXXXX.p8"

if (-not (Test-Path -LiteralPath $p8Path)) {
    throw "File not found: $p8Path"
}
$p8Content = Get-Content -LiteralPath $p8Path -Raw

Set-Secret -Name "APPLE_TEAM_ID" -Value $teamId
Set-Secret -Name "APPLE_BUNDLE_ID" -Value $bundleId
Set-Secret -Name "APPLE_API_KEY_ID" -Value $apiKeyId
Set-Secret -Name "APPLE_API_ISSUER_ID" -Value $issuerId
Set-Secret -Name "APPLE_API_PRIVATE_KEY" -Value $p8Content

Write-Host ""
Write-Host "Done. Re-run workflow: Build iOS IPA" -ForegroundColor Green
