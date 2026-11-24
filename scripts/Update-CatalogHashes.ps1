<#
.SYNOPSIS
    Calcula SHA256 de instaladores locales y actualiza catalog/catalog.json.
.DESCRIPTION
    No inventa hashes: solo escribe SHA256 calculados de archivos existentes.
    Uso:
      pwsh -File scripts/Update-CatalogHashes.ps1 -BaseDir "D:\Instaladores\SQL\Fix-SQL2008"
#>
param(
    [Parameter(Mandatory=$true)][string]$BaseDir,
    [string]$CatalogPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog\catalog.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CatalogPath)) { throw "Catalog not found: $CatalogPath" }
$catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$files = Get-ChildItem -Path $BaseDir -Recurse -File -ErrorAction SilentlyContinue

$updated = 0
foreach ($installer in @($catalog.installers)) {
    $match = @($files | Where-Object { $_.Name -ieq $installer.name } | Select-Object -First 1)
    if ($match.Count -eq 0) { continue }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($match[0].FullName)
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
    $installer.sha256 = $hash
    if ($installer.PSObject.Properties.Name -contains 'size') { $installer.size = [int64]$match[0].Length }
    $installer | Add-Member -NotePropertyName 'verifiedAt' -NotePropertyValue (Get-Date).ToString('o') -Force
    $installer | Add-Member -NotePropertyName 'verifiedFrom' -NotePropertyValue $match[0].FullName -Force
    $updated++
    Write-Host "OK $($installer.name) => $hash"
}

$catalog.generatedAt = (Get-Date).ToString('o')
$catalog | ConvertTo-Json -Depth 8 | Out-File -FilePath $CatalogPath -Encoding utf8 -Force
Write-Host "Updated $updated installer(s) in $CatalogPath"
