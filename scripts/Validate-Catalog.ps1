<# 
.SYNOPSIS
    Valida la estructura y coherencia básica de catalog/catalog.json.
#>
param(
    [string]$CatalogPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog\catalog.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CatalogPath)) { throw "Catalog not found: $CatalogPath" }
$c = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json

$errors = New-Object System.Collections.Generic.List[string]
if (-not $c.schemaVersion) { $errors.Add('Missing schemaVersion') }
if (-not $c.installers -or $c.installers.Count -lt 1) { $errors.Add('Missing installers') }

$names = @{}
foreach ($i in @($c.installers)) {
    foreach ($req in @('name','product','sp','kb','arch','lang','size')) {
        if (-not ($i.PSObject.Properties.Name -contains $req)) { $errors.Add("Missing $req in $($i.name)") }
    }
    if ($i.name) {
        if ($names.ContainsKey($i.name)) { $errors.Add("Duplicate name: $($i.name)") }
        $names[$i.name] = $true
        if ($i.name -notmatch '^SQLServer.+\.exe$') { $errors.Add("Invalid name format: $($i.name)") }
    }
    if ($i.arch -notin @('x64','x86','ia64')) { $errors.Add("Invalid arch: $($i.name)") }
    if ($i.size -le 0) { $errors.Add("Invalid size: $($i.name)") }
    if ($i.sha256) {
        if ([string]$i.sha256 -notmatch '^[a-fA-F0-9]{64}$') { $errors.Add("Invalid sha256: $($i.name)") }
    }
    if ($i.directUrl -and [string]$i.directUrl -notmatch '^https://') { $errors.Add("directUrl must be https: $($i.name)") }
    if ($i.support -and [string]$i.support -notmatch '^https://') { $errors.Add("support must be https: $($i.name)") }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "Catalog validation failed: $($errors.Count) error(s)"
}

Write-Host "Catalog OK: $($c.installers.Count) installers, schemaVersion=$($c.schemaVersion)"
