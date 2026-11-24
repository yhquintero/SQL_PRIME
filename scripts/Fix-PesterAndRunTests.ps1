<# 
.SYNOPSIS
    Instala/actualiza Pester v5 y ejecuta los tests de SQL PRIME.
.DESCRIPTION
    Diseñado para Windows PowerShell 5.1 y PowerShell 7+.
    - Instala Pester v5 en Scope CurrentUser.
    - Si falla por permisos, indica cómo ejecutar como Administrador.
    - Importa Pester v5 y ejecuta Invoke-Pester sobre .\tests.
.USAGE
    Desde la raíz del repo:
      pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Fix-PesterAndRunTests.ps1
    O como Administrador si es necesario.
#>

[CmdletBinding()]
param(
    [string]$TestsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'tests'),
    [switch]$SkipInstall,
    [switch]$RunAsAdminHintOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Host "SQL PRIME - Fix Pester & Run Tests" -ForegroundColor Magenta
Write-Host "PowerShell: $($PSVersionTable.PSVersion)  Edition: $($PSVersionTable.PSEdition)"

$isAdmin = Test-IsAdmin
if ($isAdmin) { Write-Ok "Ejecutando como Administrador" } else { Write-Warn2 "No estás como Administrador (puede ser necesario si CurrentUser falla)" }

# Mostrar Pester disponible
Write-Step "Módulos Pester disponibles"
Get-Module Pester -ListAvailable | Select-Object Name,Version,ModuleBase | Format-Table -AutoSize | Out-String | Write-Host

if (-not $SkipInstall) {
    Write-Step "Preparando instalación de Pester v5"

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

    # Asegurar ruta CurrentUser
    $userModPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
    if (-not (Test-Path -LiteralPath $userModPath)) {
        New-Item -ItemType Directory -Path $userModPath -Force | Out-Null
        Write-Ok "Creada ruta de módulos: $userModPath"
    }

    # Asegurar PSGallery (PowerShellGet v2)
    try {
        $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if (-not $repo) {
            Register-PSRepository -Default -ErrorAction SilentlyContinue
            $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        }
        if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }
    } catch { Write-Warn2 "PSGallery (v2): $($_.Exception.Message)" }

    $installed = $false

    # Estrategia 1: PSResourceGet (PS7+)
    if (-not $installed -and (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
        try {
            Write-Step "Intento 1: Install-PSResource (CurrentUser)"
            Install-PSResource -Name Pester -Scope CurrentUser -TrustRepository -Reinstall -ErrorAction Stop | Out-Null
            $installed = $true
            Write-Ok "Pester instalado vía Install-PSResource (CurrentUser)"
        } catch { Write-Warn2 "Install-PSResource CurrentUser falló: $($_.Exception.Message)" }
        if (-not $installed -and $isAdmin) {
            try {
                Write-Step "Intento 1b: Install-PSResource (AllUsers)"
                Install-PSResource -Name Pester -Scope AllUsers -TrustRepository -Reinstall -ErrorAction Stop | Out-Null
                $installed = $true
                Write-Ok "Pester instalado vía Install-PSResource (AllUsers)"
            } catch { Write-Warn2 "Install-PSResource AllUsers falló: $($_.Exception.Message)" }
        }
    }

    # Estrategia 2: Install-Module (PowerShellGet v2)
    if (-not $installed) {
        try {
            Write-Step "Intento 2: Install-Module (CurrentUser)"
            Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -Repository PSGallery -ErrorAction Stop
            $installed = $true
            Write-Ok "Pester instalado vía Install-Module (CurrentUser)"
        } catch { Write-Warn2 "Install-Module CurrentUser falló: $($_.Exception.Message)" }
    }
    if (-not $installed -and $isAdmin) {
        try {
            Write-Step "Intento 2b: Install-Module (AllUsers)"
            Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber -Repository PSGallery -ErrorAction Stop
            $installed = $true
            Write-Ok "Pester instalado vía Install-Module (AllUsers)"
        } catch { Write-Warn2 "Install-Module AllUsers falló: $($_.Exception.Message)" }
    }

    # Estrategia 3: Save-Module + copiar a CurrentUser
    if (-not $installed) {
        try {
            Write-Step "Intento 3: Save-Module + copia manual a CurrentUser"
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ("pester-save-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null
            Save-Module -Name Pester -MinimumVersion 5.0.0 -Path $tmp -Repository PSGallery -Force -ErrorAction Stop
            $saved = Get-ChildItem -Path $tmp -Directory | Where-Object { $_.Name -eq 'Pester' } | Select-Object -First 1
            if (-not $saved) { throw "No se encontró carpeta Pester en Save-Module" }
            $dest = Join-Path $userModPath 'Pester'
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
            Copy-Item -LiteralPath $saved.FullName -Destination $dest -Recurse -Force
            $installed = $true
            Write-Ok "Pester copiado a $dest"
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        } catch { Write-Warn2 "Save-Module/copia falló: $($_.Exception.Message)" }
    }

    if (-not $installed) {
        Write-Err "No se pudo instalar Pester v5 automáticamente."
        Write-Host @"

Acciones manuales (ejecutar en pwsh como ADMINISTRADOR):
  Set-PSRepository PSGallery -InstallationPolicy Trusted
  Install-Module Pester -MinimumVersion 5.0.0 -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber

Alternativa moderna (PS7+):
  Install-PSResource -Name Pester -Scope AllUsers -TrustRepository

Luego vuelve a ejecutar:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Fix-PesterAndRunTests.ps1 -SkipInstall
"@ -ForegroundColor Yellow
        exit 1
    }
}

# Cargar Pester v5
Write-Step "Cargando Pester v5"
# Quitar Pester viejo cargado en sesión
Get-Module Pester | Remove-Module -Force -ErrorAction SilentlyContinue
try {
    Import-Module Pester -MinimumVersion 5.0.0 -Force -ErrorAction Stop
    $v = (Get-Module Pester).Version
    Write-Ok "Pester cargado: $v"
} catch {
    Write-Err "No se pudo cargar Pester v5: $($_.Exception.Message)"
    Write-Host "Módulos disponibles:" -ForegroundColor Yellow
    Get-Module Pester -ListAvailable | Select Name,Version,ModuleBase | Format-Table -AutoSize | Out-String | Write-Host
    exit 1
}

# Ejecutar tests
Write-Step "Ejecutando tests: $TestsPath"
if (-not (Test-Path -LiteralPath $TestsPath)) {
    Write-Err "No existe la ruta de tests: $TestsPath"
    exit 1
}

$config = New-PesterConfiguration
$config.Run.Path = $TestsPath
$config.Output.Verbosity = 'Detailed'
$config.Run.PassThru = $true

$result = Invoke-Pester -Configuration $config

Write-Step "Resumen"
Write-Host "Total: $($result.TotalCount)  Passed: $($result.PassedCount)  Failed: $($result.FailedCount)  Skipped: $($result.SkippedCount)"

if ($result.FailedCount -gt 0) {
    Write-Err "Hay tests fallidos. Pega el resultado y lo corrijo."
    exit 1
}

Write-Ok "Todos los tests pasaron."
exit 0
