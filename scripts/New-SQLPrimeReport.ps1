#requires -Version 5.1
<#
.SYNOPSIS
Generates a professional HTML report from SQL PRIME catalog and local installer inventory.
Includes futuristic progress bars for inventory coverage, SHA-256 coverage and per-item health.
#>
[CmdletBinding()]
param(
    [string]$BaseDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-HtmlText {
    param([object]$Value)
    [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-SQLPrimePercent {
    param([int]$Numerator, [int]$Denominator)
    if ($Denominator -le 0) { return 0 }
    return [int][math]::Round((100 * $Numerator) / $Denominator)
}

$designModule = Join-Path $BaseDir 'modules\DesignSystem.ps1'
if (Test-Path -LiteralPath $designModule) { . $designModule }
$cssVars = ConvertTo-SQLPrimeCssVariables -BaseDir $BaseDir

$catalogPath = Join-Path $BaseDir 'catalog\catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath)) { throw "catalog.json not found: $catalogPath" }
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json

$inventoryModule = Join-Path $BaseDir 'modules\Inventory.ps1'
$inventory = @()
if (Test-Path -LiteralPath $inventoryModule) {
    . $inventoryModule
    $inventory = @(Get-InstallerInventory -BaseDir $BaseDir)
}
$inventoryNames = @($inventory | ForEach-Object { [string]$_.Name })

if (-not $OutputPath) {
    $outDir = Join-Path $BaseDir 'reports'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $OutputPath = Join-Path $outDir ("SQL_PRIME_Report_{0}.html" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

$items = @($catalog.installers)
$total = $items.Count
$presentCount = 0
$hashCount = 0

$rows = foreach ($i in $items) {
    $name = [string]$i.name
    $isPresent = @($inventoryNames | Where-Object { $_ -ieq $name }).Count -gt 0
    $hasHash = [bool]$i.sha256
    if ($isPresent) { $presentCount++ }
    if ($hasHash) { $hashCount++ }

    $health = if ($isPresent -and $hasHash) { 100 } elseif ($isPresent) { 50 } else { 0 }
    $healthTone = if ($health -eq 100) { 'ok' } elseif ($health -eq 50) { 'warn' } else { 'bad' }
    $statusText = if ($isPresent) { 'Presente' } else { 'Faltante' }
    $statusTone = if ($isPresent) { 'ok' } else { 'bad' }
    $shaText = if ($hasHash) { ConvertTo-HtmlText $i.sha256 } else { 'PENDING' }

    "<tr><td class='mono'>$((ConvertTo-HtmlText $name))</td><td>$((ConvertTo-HtmlText $i.product))</td><td>$((ConvertTo-HtmlText $i.sp))</td><td>$((ConvertTo-HtmlText $i.arch))</td><td>$((ConvertTo-HtmlText $i.lang))</td><td><span class='badge $statusTone'>$statusText</span></td><td><div class='mini'><i class='$healthTone' style='width:$health%'></i></div><small>$health%</small></td><td class='mono small'>$shaText</td></tr>"
}

$inventoryPct = Get-SQLPrimePercent -Numerator $presentCount -Denominator $total
$integrityPct = Get-SQLPrimePercent -Numerator $hashCount -Denominator $total
$overallPct = [int][math]::Round(($inventoryPct + $integrityPct) / 2)
$missingCount = $total - $presentCount
$pendingHashCount = $total - $hashCount

$html = @"
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SQL PRIME · Reporte de cobertura</title>
<style>
:root{$cssVars}
*{box-sizing:border-box}
body{font-family:Segoe UI,Segoe UI Emoji,Arial,sans-serif;margin:0;padding:32px 24px;color:var(--txt);background:radial-gradient(1000px 520px at 12% -10%,rgba(34,211,238,.14),transparent 60%),radial-gradient(900px 500px at 100% 0%,rgba(244,114,182,.10),transparent 55%),var(--bg)}
.shell{max-width:1120px;margin:0 auto}
header{border:1px solid var(--line);border-radius:18px;padding:22px 24px;background:linear-gradient(140deg,rgba(15,23,42,.95),rgba(10,16,34,.92));box-shadow:0 0 34px rgba(34,211,238,.08),inset 0 1px 0 rgba(255,255,255,.04)}
.kicker{font-size:11px;letter-spacing:.28em;text-transform:uppercase;color:var(--cyan);font-weight:700}
h1{margin:8px 0 6px;font-size:29px;letter-spacing:-.02em;text-shadow:0 0 18px rgba(139,92,246,.55)}
h1 span{background:linear-gradient(90deg,var(--cyan),var(--violet) 55%,var(--pink));-webkit-background-clip:text;background-clip:text;color:transparent}
.muted{color:var(--muted);font-size:12px;margin:2px 0}
.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:18px 0 22px}
.card{border:1px solid var(--line);border-radius:14px;padding:16px;background:linear-gradient(160deg,var(--panel),#0b1224);box-shadow:0 12px 28px rgba(0,0,0,.28),inset 0 0 0 1px rgba(255,255,255,.02)}
.card .label{font-size:11px;text-transform:uppercase;letter-spacing:.14em;color:var(--muted)}
.card .metric{font-size:28px;font-weight:800;margin:6px 0 2px}
.card .detail{font-size:12px;color:var(--muted)}
.bar{height:10px;border-radius:999px;background:#080f20;overflow:hidden;box-shadow:inset 0 0 0 1px rgba(139,92,246,.28);margin-top:10px}
.bar>i{display:block;height:100%;border-radius:999px;position:relative;background:linear-gradient(90deg,var(--cyan),var(--violet) 55%,var(--pink));box-shadow:0 0 16px rgba(139,92,246,.65)}
.bar>i::after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent,rgba(255,255,255,.45),transparent);transform:translateX(-100%);animation:sheen 3.4s ease-in-out infinite}
.bar.alt>i{background:linear-gradient(90deg,var(--green),var(--cyan) 55%,var(--violet));box-shadow:0 0 16px rgba(34,211,238,.55)}
.bar.total>i{background:linear-gradient(90deg,var(--violet),var(--pink) 60%,var(--cyan));box-shadow:0 0 18px rgba(244,114,182,.55)}
@keyframes sheen{60%,100%{transform:translateX(100%)}}
@media(prefers-reduced-motion:reduce){.bar>i::after{animation:none}}
.panel{border:1px solid var(--line);border-radius:16px;background:rgba(15,23,42,.88);padding:18px;box-shadow:0 0 28px rgba(139,92,246,.07)}
h2{font-size:15px;margin:0 0 12px;letter-spacing:.06em;text-transform:uppercase;color:var(--cyan)}
table{border-collapse:collapse;width:100%}
th,td{border-bottom:1px solid var(--line);padding:9px 10px;text-align:left;font-size:12px;vertical-align:middle}
th{color:var(--muted);font-size:10px;letter-spacing:.12em;text-transform:uppercase;border-bottom:1px solid var(--violet)}
tr:hover td{background:rgba(34,211,238,.035)}
.mono{font-family:Consolas,"Courier New",monospace;font-size:11px}
.small{font-size:11px}
.badge{display:inline-block;padding:3px 9px;border-radius:999px;font-size:10px;font-weight:800;letter-spacing:.06em;text-transform:uppercase}
.badge.ok{color:var(--green);background:rgba(52,211,153,.12);box-shadow:inset 0 0 0 1px rgba(52,211,153,.35)}
.badge.bad{color:var(--red);background:rgba(251,113,133,.12);box-shadow:inset 0 0 0 1px rgba(251,113,133,.32)}
.mini{width:82px;height:7px;border-radius:999px;background:#080f20;display:inline-block;vertical-align:middle;overflow:hidden;box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)}
.mini>i{display:block;height:100%;border-radius:999px}
.mini>i.ok{background:linear-gradient(90deg,var(--green),var(--cyan));box-shadow:0 0 8px rgba(52,211,153,.7)}
.mini>i.warn{background:linear-gradient(90deg,var(--amber),var(--pink));box-shadow:0 0 8px rgba(251,191,36,.6)}
.mini>i.bad{background:#3b1d2c}
td small{color:var(--muted);margin-left:6px}
footer{margin-top:16px;color:var(--muted);font-size:11px;display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap}
.legend{display:flex;gap:14px;flex-wrap:wrap}
.legend b{font-weight:600}
@media(max-width:760px){.cards{grid-template-columns:1fr}body{padding:18px 12px}}
@media print{body{background:#fff;color:#111}.card,.panel,header{box-shadow:none;background:#fff;border-color:#ccc}.bar>i::after{animation:none}}
</style>
</head><body>
<div class="shell">
<header>
  <div class="kicker">SQL PRIME · Catalogue intelligence</div>
  <h1><span>Reporte de cobertura</span></h1>
  <p class="muted">Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
  <p class="muted">Base: $((ConvertTo-HtmlText $BaseDir)) · Instaladores en catálogo: $total</p>
</header>

<section class="cards">
  <div class="card">
    <div class="label">Inventario local</div>
    <div class="metric">$presentCount / $total</div>
    <div class="detail">$missingCount faltante(s)</div>
    <div class="bar"><i style="width:$inventoryPct%"></i></div>
  </div>
  <div class="card">
    <div class="label">Integridad SHA-256</div>
    <div class="metric">$hashCount / $total</div>
    <div class="detail">$pendingHashCount hash(es) pendiente(s)</div>
    <div class="bar alt"><i style="width:$integrityPct%"></i></div>
  </div>
  <div class="card">
    <div class="label">Cobertura global</div>
    <div class="metric">$overallPct%</div>
    <div class="detail">Media de inventario + integridad</div>
    <div class="bar total"><i style="width:$overallPct%"></i></div>
  </div>
</section>

<section class="panel">
  <h2>Detalle por instalador</h2>
  <table><thead><tr><th>Instalador</th><th>Producto</th><th>SP</th><th>Arch</th><th>Lang</th><th>Local</th><th>Salud</th><th>SHA256</th></tr></thead>
  <tbody>
$($rows -join "`n")
  </tbody></table>
</section>

<footer>
  <div class="legend"><b>🟢 Completo</b><b>🟡 Sin hash</b><b>🔴 Faltante</b></div>
  <div>SQL PRIME · Diagnostica. Repara. Actualiza.</div>
</footer>
</div>
</body></html>
"@

$html | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Report generated: $OutputPath"
