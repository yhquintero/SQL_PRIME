#requires -Version 5.1
<#
.SYNOPSIS
Convierte un reporte HTML de SQL PRIME a PDF usando Microsoft Edge headless.
No añade dependencias de pago ni envía datos fuera del equipo.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$HtmlPath,
    [string]$OutputPath = '',
    [string]$EdgePath = '',
    [int]$VirtualTimeBudgetMs = 2000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $HtmlPath)) { throw "No existe el HTML: $HtmlPath" }
$htmlItem = Get-Item -LiteralPath $HtmlPath

if (-not $OutputPath) { $OutputPath = [System.IO.Path]::ChangeExtension($htmlItem.FullName, '.pdf') }
$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

if (-not $EdgePath) {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { $EdgePath = $candidate; break }
    }
}
if (-not $EdgePath -or -not (Test-Path -LiteralPath $EdgePath)) {
    throw 'No se encontró Microsoft Edge/Chrome. Instala Edge o pasa -EdgePath.'
}

$uri = ([System.Uri]$htmlItem.FullName).AbsoluteUri
$profile = Join-Path ([System.IO.Path]::GetTempPath()) ('sqlprime-pdf-' + [guid]::NewGuid().ToString('N'))
$argsList = @(
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    "--user-data-dir=`"$profile`"",
    '--no-pdf-header-footer',
    "--virtual-time-budget=$VirtualTimeBudgetMs",
    "--print-to-pdf=`"$OutputPath`"",
    "`"$uri`""
)

try {
    $proc = Start-Process -FilePath $EdgePath -ArgumentList $argsList -WindowStyle Hidden -PassThru -Wait
    if ($proc.ExitCode -ne 0) { throw "Edge terminó con código $($proc.ExitCode)" }
} finally {
    if (Test-Path -LiteralPath $profile) { Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue }
}

if (-not (Test-Path -LiteralPath $OutputPath)) { throw 'Edge no generó el PDF.' }
$pdf = Get-Item -LiteralPath $OutputPath
if ($pdf.Length -lt 1000) { throw "PDF demasiado pequeño: $($pdf.Length) bytes" }
"PDF generado: $($pdf.FullName) ($($pdf.Length) bytes)"
