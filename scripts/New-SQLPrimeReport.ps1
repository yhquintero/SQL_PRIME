#requires -Version 5.1
<#
.SYNOPSIS
Generates a simple HTML report from SQL PRIME catalog and local installer inventory.
#>
[CmdletBinding()]
param(
    [string]$BaseDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$catalogPath = Join-Path $BaseDir 'catalog\catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath)) { throw "catalog.json not found: $catalogPath" }
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json

$inventoryModule = Join-Path $BaseDir 'modules\Inventory.ps1'
$inventory = @()
if (Test-Path -LiteralPath $inventoryModule) {
    . $inventoryModule
    $inventory = @(Get-InstallerInventory -BaseDir $BaseDir)
}

if (-not $OutputPath) {
    $outDir = Join-Path $BaseDir 'reports'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $OutputPath = Join-Path $outDir ("SQL_PRIME_Report_{0}.html" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

$rows = foreach ($i in $catalog.installers) {
    $found = @($inventory | Where-Object { $_.Name -ieq $i.name }).Count -gt 0
    $sha = if ($i.sha256) { [string]$i.sha256 } else { 'PENDING' }
    $status = if ($found) { 'Present' } else { 'Missing' }
    "<tr><td>$([System.Net.WebUtility]::HtmlEncode($i.name))</td><td>$($i.product)</td><td>$($i.sp)</td><td>$($i.arch)</td><td>$($i.lang)</td><td>$status</td><td style='font-family:monospace;font-size:12px'>$sha</td></tr>"
}

$html = @"
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SQL PRIME Report</title>
<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;background:#0f172a;color:#e2e8f0} table{border-collapse:collapse;width:100%;background:#111827} th,td{border:1px solid #334155;padding:8px;text-align:left;vertical-align:top} th{background:#1f2937} .muted{color:#94a3b8}</style>
</head><body>
<h1>SQL PRIME - Reporte</h1>
<p class="muted">Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<p class="muted">Base: $([System.Net.WebUtility]::HtmlEncode($BaseDir))</p>
<table><thead><tr><th>Instalador</th><th>Producto</th><th>SP</th><th>Arch</th><th>Lang</th><th>Local</th><th>SHA256</th></tr></thead>
<tbody>
$($rows -join "`n")
</tbody></table>
</body></html>
"@

$html | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Report generated: $OutputPath"
