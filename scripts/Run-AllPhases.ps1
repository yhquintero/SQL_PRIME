#requires -Version 5.1
<#
.SYNOPSIS
Orchestrates SQL PRIME Phase 0-3 checks/scaffolds that can be automated locally.

.DESCRIPTION
Runs verifiable local steps (tests, catalog validation, report, optional .NET tests, optional dev ECC cert)
and prints a clear status of what remains manual for Phases 1-3.
#>
[CmdletBinding()]
param(
    [string]$BaseDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$SkipPester,
    [switch]$SkipDotNet,
    [switch]$GenerateDevCert,
    [string]$CertDnsName = 'localhost'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }

$results = [ordered]@{}
Push-Location $BaseDir
try {
    Write-Host "SQL PRIME - Run All Phases (automatable checks)" -ForegroundColor Magenta
    Write-Host "BaseDir: $BaseDir"

    # Phase 0: Pester
    Write-Step "Phase 0 - Pester tests"
    if ($SkipPester) {
        Write-Warn2 "Pester omitido (-SkipPester)"
        $results['Phase0.Pester'] = 'SKIPPED'
    } else {
        $pesterScript = Join-Path $BaseDir 'scripts\Fix-PesterAndRunTests.ps1'
        if (-not (Test-Path -LiteralPath $pesterScript)) { throw "No encontrado: $pesterScript" }
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $pesterScript -SkipInstall
        if ($LASTEXITCODE -ne 0) { throw "Pester failed" }
        $results['Phase0.Pester'] = 'OK'
    }

    # Phase 0: Catalog validation
    Write-Step "Phase 0 - Catalog validation"
    $catalogScript = Join-Path $BaseDir 'scripts\Validate-Catalog.ps1'
    & pwsh -NoProfile -File $catalogScript -CatalogPath (Join-Path $BaseDir 'catalog\catalog.json')
    if ($LASTEXITCODE -ne 0) { throw "Catalog validation failed" }
    $results['Phase0.Catalog'] = 'OK'

    # Phase 0: Missing hashes report
    Write-Step "Phase 0 - Missing SHA256 hashes"
    $catalog = Get-Content -LiteralPath (Join-Path $BaseDir 'catalog\catalog.json') -Raw | ConvertFrom-Json
    $missing = @($catalog.installers | Where-Object { -not $_.sha256 })
    if ($missing.Count -gt 0) {
        Write-Warn2 "Faltan SHA256 oficiales en $($missing.Count) instalador(es):"
        $missing | ForEach-Object { Write-Host " - $($_.name)" -ForegroundColor Yellow }
        $results['Phase0.Hashes'] = "PENDING ($($missing.Count))"
    } else {
        Write-Ok "Todos los instaladores tienen SHA256"
        $results['Phase0.Hashes'] = 'OK'
    }

    # Phase 1: HTML report scaffold
    Write-Step "Phase 1 - Generate HTML report"
    $reportScript = Join-Path $BaseDir 'scripts\New-SQLPrimeReport.ps1'
    & pwsh -NoProfile -File $reportScript -BaseDir $BaseDir
    if ($LASTEXITCODE -ne 0) { throw "Report generation failed" }
    $results['Phase1.Report'] = 'OK'

    # Phase 2: .NET build/test
    Write-Step "Phase 2 - .NET restore/build/test"
    if ($SkipDotNet) {
        Write-Warn2 ".NET omitido (-SkipDotNet)"
        $results['Phase2.DotNet'] = 'SKIPPED'
    } elseif (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warn2 "dotnet no encontrado; omitiendo Fase 2 .NET"
        $results['Phase2.DotNet'] = 'SKIPPED (dotnet not found)'
    } else {
        dotnet test (Join-Path $BaseDir 'SQLPrime.sln') -c Release
        if ($LASTEXITCODE -ne 0) { throw "dotnet test failed" }
        $results['Phase2.DotNet'] = 'OK'
    }

    # Phase 3: optional dev ECC cert
    Write-Step "Phase 3 - Dev ECDSA cert (optional)"
    if ($GenerateDevCert) {
        $certScript = Join-Path $BaseDir 'scripts\New-SQLPrimeEccCert.ps1'
        & pwsh -NoProfile -File $certScript -DnsName $CertDnsName
        if ($LASTEXITCODE -ne 0) { throw "Dev cert generation failed" }
        $results['Phase3.DevCert'] = 'OK'
    } else {
        Write-Warn2 "Cert dev omitido. Usa -GenerateDevCert para generar ECDSA P-256 local."
        $results['Phase3.DevCert'] = 'SKIPPED'
    }

    # Summary
    Write-Step "Resumen automatizable"
    foreach ($k in $results.Keys) {
        $v = $results[$k]
        $color = if ($v -like 'OK*') { 'Green' } elseif ($v -like 'SKIPPED*') { 'Yellow' } elseif ($v -like 'PENDING*') { 'Yellow' } else { 'Red' }
        Write-Host ("{0,-24} {1}" -f $k, $v) -ForegroundColor $color
    }

    Write-Step "Pendiente manual / no automatizable completamente"
    @(
        'Phase0: poblar 3 SHA256 x86 con instaladores oficiales verificados (sin inventar)',
        'Phase0: completar separación UI/Core del monolítico (Repair/UI-Theme/flujos UI-coupled)',
        'Phase1: wizard WPF Diagnosticar->Respaldar->Aplicar->Verificar integrado en UI',
        'Phase1: centro descargas pro (ETA/velocidad/pausa por archivo/cola persistente)',
        'Phase1: reporte antes/después + PDF, i18n/accesibilidad integradas en UI',
        'Phase2: portar lógica completa a .NET 8 con paridad, MVVM/DI/async, MSIX/MSI firmado',
        'Phase3: cert ECDSA real + rotación, OIDC/MFA/RBAC, auditoría persistente, WAF/proxy, validación TLS en producción'
    ) | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkYellow }

    Write-Ok "Run-AllPhases completado (checks automatizables)."
    exit 0
}
catch {
    Write-Fail $_.Exception.Message
    exit 1
}
finally {
    Pop-Location
}
