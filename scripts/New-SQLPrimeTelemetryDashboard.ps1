#requires -Version 5.1
<#
.SYNOPSIS
Generates a local telemetry dashboard from logs/sql_prime.jsonl with futuristic SVG sparklines.
No external services: all data stays on the machine.
#>
[CmdletBinding()]
param(
    [string]$BaseDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputPath = '',
    [ValidateRange(7, 90)][int]$Days = 14
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-HtmlText {
    param([object]$Value)
    [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-SQLPrimeSparkline {
    param([int[]]$Values, [int]$Width = 520, [int]$Height = 90)

    if ($Values.Count -eq 0) { return @{ Line = ''; Area = '' } }
    $max = [Math]::Max(1, ($Values | Measure-Object -Maximum).Maximum)
    $step = if ($Values.Count -gt 1) { $Width / ($Values.Count - 1) } else { 0 }
    $points = @()
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $x = [math]::Round($i * $step, 1)
        $y = [math]::Round($Height - (($Values[$i] / $max) * ($Height - 12)) - 6, 1)
        $points += "$x,$y"
    }
    $line = $points -join ' '
    $area = "0,$Height $line $Width,$Height"
    return @{ Line = $line; Area = $area; Max = $max }
}

$designModule = Join-Path $BaseDir 'modules\DesignSystem.ps1'
if (Test-Path -LiteralPath $designModule) { . $designModule }
$cssVars = if (Get-Command ConvertTo-SQLPrimeCssVariables -ErrorAction SilentlyContinue) {
    ConvertTo-SQLPrimeCssVariables -BaseDir $BaseDir
} else {
    '--bg:#070b18;--panel:#0f172a;--line:#22304d;--txt:#e6f1ff;--muted:#93a4c3;--cyan:#22d3ee;--violet:#8b5cf6;--pink:#f472b6;--green:#34d399;--amber:#fbbf24;--red:#fb7185'
}

$logPath = Join-Path $BaseDir 'logs\sql_prime.jsonl'
$entries = @()
if (Test-Path -LiteralPath $logPath) {
    foreach ($line in (Get-Content -LiteralPath $logPath)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $entries += ($line | ConvertFrom-Json) } catch { }
    }
}

$today = (Get-Date).Date
$dayList = @()
for ($i = $Days - 1; $i -ge 0; $i--) { $dayList += $today.AddDays(-$i) }
$dayKeys = @($dayList | ForEach-Object { $_.ToString('yyyy-MM-dd') })
$countsByDay = @{}
foreach ($key in $dayKeys) { $countsByDay[$key] = 0 }

$levels = @{ INFO = 0; WARN = 0; ERROR = 0; DEBUG = 0; AUDIT = 0 }
$components = @{}
$operations = [System.Collections.Generic.HashSet[string]]::new()
foreach ($e in $entries) {
    $key = $null
    try {
        $ts = [datetimeoffset]::Parse([string]$e.ts).DateTime.Date.ToString('yyyy-MM-dd')
        if ($countsByDay.ContainsKey($ts)) { $key = $ts; $countsByDay[$ts]++ }
    } catch { }
    $level = if ($e.PSObject.Properties.Name -contains 'level') { ([string]$e.level).ToUpperInvariant() } else { 'INFO' }
    if (-not $levels.ContainsKey($level)) { $levels[$level] = 0 }
    $levels[$level]++
    $component = if ($e.PSObject.Properties.Name -contains 'component') { [string]$e.component } else { 'app' }
    if (-not $components.ContainsKey($component)) { $components[$component] = 0 }
    $components[$component]++
    if ($e.PSObject.Properties.Name -contains 'operationId' -and $e.operationId) { $null = $operations.Add([string]$e.operationId) }
}

$values = @($dayKeys | ForEach-Object { [int]$countsByDay[$_] })
$spark = Get-SQLPrimeSparkline -Values $values -Width 520 -Height 90
$totalEvents = $entries.Count
$errorRate = if ($totalEvents -gt 0) { [int][math]::Round(100 * $levels.ERROR / $totalEvents) } else { 0 }
$successRate = 100 - $errorRate

$levelRows = foreach ($name in @('INFO','AUDIT','WARN','ERROR','DEBUG')) {
    $count = [int]$levels[$name]
    $pct = if ($totalEvents -gt 0) { [int][math]::Round(100 * $count / $totalEvents) } else { 0 }
    $tone = if ($name -eq 'ERROR') { 'red' } elseif ($name -eq 'WARN') { 'amber' } else { 'cyan' }
    "<tr><td><span class='dot $tone'></span>$name</td><td>$count</td><td><div class='mini'><i class='$tone' style='width:$pct%'></i></div></td><td>$pct%</td></tr>"
}

$componentRows = foreach ($c in ($components.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 8)) {
    $pct = if ($totalEvents -gt 0) { [int][math]::Round(100 * $c.Value / $totalEvents) } else { 0 }
    "<tr><td>$((ConvertTo-HtmlText $c.Key))</td><td>$($c.Value)</td><td><div class='mini'><i style='width:$pct%'></i></div></td><td>$pct%</td></tr>"
}

$dayLabels = @($dayList | ForEach-Object { $_.ToString('dd/MM') })
$labelStep = [Math]::Max(1, [int][math]::Ceiling($Days / 7))
$labels = @()
for ($i = 0; $i -lt $dayLabels.Count; $i += $labelStep) {
    $x = if ($values.Count -gt 1) { [math]::Round($i * 520 / ($values.Count - 1), 1) } else { 0 }
    $labels += "<text x='$x' y='108' text-anchor='middle'>$($dayLabels[$i])</text>"
}

if (-not $OutputPath) {
    $outDir = Join-Path $BaseDir 'reports'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $OutputPath = Join-Path $outDir ("SQL_PRIME_Telemetry_{0}.html" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

$html = @"
<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SQL PRIME · Telemetría local</title>
<style>
:root{$cssVars}
*{box-sizing:border-box}
body{font-family:Segoe UI,Segoe UI Emoji,Arial,sans-serif;margin:0;padding:30px 22px;color:var(--txt);background:radial-gradient(900px 480px at 10% -10%,rgba(34,211,238,.13),transparent 60%),var(--bg)}
.shell{max-width:1100px;margin:0 auto}
header,.panel{border:1px solid var(--line);border-radius:16px;padding:20px;background:linear-gradient(150deg,var(--panel),#0b1224);box-shadow:0 0 30px rgba(139,92,246,.08)}
.kicker{font-size:10px;letter-spacing:.26em;text-transform:uppercase;color:var(--cyan);font-weight:700}
h1{margin:8px 0 6px;font-size:26px;background:linear-gradient(90deg,var(--cyan),var(--violet) 55%,var(--pink));-webkit-background-clip:text;background-clip:text;color:transparent}
h2{font-size:14px;margin:0 0 12px;text-transform:uppercase;letter-spacing:.08em;color:var(--cyan)}
.muted{color:var(--muted);font-size:12px}
.cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:18px 0}
.card{border:1px solid var(--line);border-radius:13px;padding:14px;background:#0b1224}
.card .label{font-size:10px;text-transform:uppercase;letter-spacing:.13em;color:var(--muted)}
.card .metric{font-size:24px;font-weight:800;margin:5px 0 2px}
.bar{height:9px;border-radius:999px;background:#080f20;overflow:hidden;box-shadow:inset 0 0 0 1px rgba(139,92,246,.28);margin-top:9px}
.bar>i{display:block;height:100%;border-radius:999px;background:linear-gradient(90deg,var(--cyan),var(--violet) 55%,var(--pink));box-shadow:0 0 14px rgba(139,92,246,.6)}
.bar.ok>i{background:linear-gradient(90deg,var(--green),var(--cyan))}
.bar>i.red{background:linear-gradient(90deg,var(--red),var(--violet))}
svg{width:100%;height:auto;display:block}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:14px}
table{border-collapse:collapse;width:100%}th,td{border-bottom:1px solid var(--line);padding:7px 9px;text-align:left;font-size:12px}th{color:var(--muted);font-size:10px;text-transform:uppercase;letter-spacing:.1em;border-bottom-color:var(--violet)}
.mini{width:82px;height:7px;border-radius:999px;background:#080f20;display:inline-block;vertical-align:middle;overflow:hidden}
.mini>i{display:block;height:100%;border-radius:999px;background:linear-gradient(90deg,var(--cyan),var(--violet))}
.mini>i.ok{background:linear-gradient(90deg,var(--green),var(--cyan))}
.mini>i.amber{background:linear-gradient(90deg,var(--amber),var(--pink))}
.mini>i.red{background:linear-gradient(90deg,var(--red),var(--violet))}
.dot{width:8px;height:8px;border-radius:50%;display:inline-block;margin-right:8px}.dot.cyan{background:var(--cyan)}.dot.amber{background:var(--amber)}.dot.red{background:var(--red)}
.labels text{fill:var(--muted);font-size:10px;font-family:Segoe UI,Arial,sans-serif}
@media(max-width:760px){.cards{grid-template-columns:1fr 1fr}.grid{grid-template-columns:1fr}}
@media print{body{background:#fff;color:#111}header,.panel,.card{box-shadow:none;background:#fff}}
</style>
</head><body><div class="shell">
<header><div class="kicker">SQL PRIME · Local telemetry</div><h1>Pulso de la herramienta</h1>
<p class="muted">Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') · Ventana: $Days días · Eventos: $totalEvents · Operaciones: $($operations.Count)</p>
</header>
<section class="cards">
  <div class="card"><div class="label">Eventos</div><div class="metric">$totalEvents</div><div class="detail">logs/sql_prime.jsonl</div></div>
  <div class="card"><div class="label">Errores</div><div class="metric">$($levels.ERROR)</div><div class="bar"><i class="red" style="width:$errorRate%"></i></div></div>
  <div class="card"><div class="label">Salud</div><div class="metric">$successRate%</div><div class="bar ok"><i style="width:$successRate%"></i></div></div>
  <div class="card"><div class="label">Operaciones</div><div class="metric">$($operations.Count)</div><div class="detail">IDs únicos trazados</div></div>
</section>
<section class="panel"><h2>Actividad diaria (sparkline)</h2>
<svg viewBox="0 0 520 120" role="img" aria-label="Eventos por día">
  <defs><linearGradient id="spark" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="var(--cyan)"/><stop offset="0.55" stop-color="var(--violet)"/><stop offset="1" stop-color="var(--pink)"/></linearGradient></defs>
  <polygon points="$($spark.Area)" fill="url(#spark)" opacity="0.13"/>
  <polyline points="$($spark.Line)" fill="none" stroke="url(#spark)" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>
  <g class="labels">$($labels -join '')</g>
</svg>
<p class="muted">Máximo diario en la ventana: $($spark.Max) evento(s).</p>
</section>
<div class="grid">
<section class="panel"><h2>Niveles</h2><table><tr><th>Nivel</th><th>Total</th><th>%</th><th>Distribución</th></tr>$($levelRows -join "`n")</table></section>
<section class="panel"><h2>Componentes</h2><table><tr><th>Componente</th><th>Total</th><th>% del total</th></tr>$($componentRows -join "`n")</table></section>
</div>
</div></body></html>
"@

$html | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Telemetry dashboard generated: $OutputPath"
