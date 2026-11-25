<#
.SYNOPSIS
    Herramienta de Reparación y Actualización SQL Server MULTIVERSIÓN con Temas
    e interfaz adaptable a la resolución de pantalla.
.DESCRIPTION
    v3.0 - Noviembre 2026 (EDICIÓN MULTIVERSIÓN)
    - Inventario recursivo de TODAS las carpetas: muestra el nombre exacto de cada
      instalador encontrado (el botón "INVENTARIO / DESCARGAS" genera un informe).
    - La detección ya NO depende del nombre de la carpeta: se lee el nombre del
      fichero (producto, SP, KB, arquitectura e idioma). Las carpetas heredadas
      (por ejemplo SQLServer2008SP3 con instaladores R2) se aceptan como válidas.
    - El idioma se lee del registro de la instancia (LCID 1033 = ENU, 3082 = ESN).
      Un paquete ESN NUNCA se ofrece para una instalación 1033/English-US.
    - Los Service Packs son acumulativos: se ofrece directamente el SP más alto
      disponible (SP4 para 2008, SP3 para 2008 R2), con respaldo a SPs inferiores.
    - Descarga automática de los instaladores ENU/ESN que falten, guardándolos en la
      carpeta heredada o en la carpeta nueva correspondiente a cada Service Pack.
    - Aviso de rama QFE/CU (10.52.x frente a 10.50.x): explica el rechazo del SP3
      con "No se actualizó ninguna característica" / exit -2068643838.
    - Reparación del servicio SQL: detecta 5597/912/3417, respalda la clave de
      FILESTREAM, la deshabilita temporalmente y arranca en modo monousuario.
    - Reparación WMI: busca el MOF/LLD en todas las rutas Shared existentes y
      reinicia el servicio winmgmt.
    - v3.0: catálogo profesional de TODAS las versiones (SQL 6.5, 7.0, 2000,
      2005, 2008, 2008 R2, 2012, 2014, 2016, 2017, 2019, 2022 y 2025) con
      Service Packs/CU, arquitecturas, idiomas, estado de soporte y enlaces
      oficiales. Selector de versión y generador de estructura de carpetas
      (RTM, ServicePacks, CumulativeUpdates, SecurityFixes, _REPARACIONES,
      _DOCUMENTACION, _LOGS, _HERRAMIENTAS) y fichas README por versión.
    - Interfaz responsive: tamaño inicial calculado desde el area util de la
      pantalla, botones siempre visibles en WrapPanel y log justo bajo el estado
      del sistema con ScrollViewer propio (no hay barra de desplazamiento global).
    - Temas claro/oscuro con colores de texto contrastados en todos los rotulos,
      incluidos los que antes tenian color fijo (estado, actualizacion y version).
      El cambio se hace con el boton de la barra: un clic rota Oscuro -> Claro ->
      Auto, muestra el modo activo y lo guarda en ui_config.json (ya no hay combo).
    - Boton CERRAR corregido: el arrastre de la barra ya no roba el Click cuando
      se pulsa sobre el texto interior del boton. Se elimino el boton maximizar.
    - Hover profesional: los botones de tema y CERRAR cambian fondo y color de
      letra al pasar el puntero (rojo en CERRAR), y el listado de versiones
      cambia fondo y color de texto. Colores adaptados a tema oscuro/claro.
    - ToolTip explicativo en todos los botones y atajos Esc (cerrar) / F5 (refrescar).
    - Reparación de servicios: activa TODOS los servicios SQL (motor, Agent,
      FILESTREAM, Browser, VSS Writer, SSAS, SSRS, SSIS, Distributed Replay),
      incluso cuando el motor ya está en ejecución, y verifica al final que
      TODOS estén Running uno por uno.
    - Botón especial DESACTIVAR SERVICIOS: detiene y pone en Disabled TODOS los
      servicios SQL instalados, con confirmación y verificación final.
    - Modal de progreso en DESACTIVAR y REPARAR: tiempo transcurrido, contador,
      barra de avance y lista de servicios/pasos en vivo. TODOS los botones
      quedan desactivados hasta que la tarea termina (finally los restaura).
    - Fix OOM: sqlservr.exe en monousuario ya no usa -NoNewWindow (volcaba el
      ERRORLOG en la consola y agotaba memoria); stdout/stderr y sqlcmd van a
      ficheros con lectura acotada.
    - BLOQUE A (Seguridad): confirmacion escribiendo DESACTIVAR, punto de
      restauracion automatico y modo simulacion sin cambios reales.
    - BLOQUE B (Gestion fina): panel con checkbox por servicio, inicio/parada
      individual con modal, diagnóstico con sc.exe qc y dependencias.
    - BLOQUE C (Informes): snapshot ANTES/DESPUES, historial en el log y
      exportacion de estado de servicios a CSV y HTML con tiempo transcurrido.
    - BLOQUE D (Robustez): timeouts y reintentos con backoff configurables en
      sql_prime_options.json, diagnóstico automatico y control de permisos.
    - BLOQUE E (UX): pestanas de acciones, semaforo 🟢/🟡/🔴 con timer y filtro
      de texto del log. Modal con ⏹ cancelar y tiempo estimado restante.
    - BLOQUE F (Automatizacion): perfiles en sql_prime_profiles.json, modo CLI
      (-StartAll/-StopAll/-Verify/-Report) y tarea programada diaria.
    - BLOQUE G (Velocidad): arranque y parada en DOS FASES (emitir todas las
      ordenes y esperar una sola vez), una sola consulta Get-Service para todos
      los servicios, sondeo adaptativo de 200 ms y esperas condicionales en la
      reparacion (antes habia sleeps fijos de 2-3 s por paso).
    - BLOQUE H (Trazabilidad): log con niveles (STEP/OK/WARN/ERROR/CMD/DEBUG/TIME),
      comandos exactos ejecutados, duracion por fase y total, comparativa
      ANTES/DESPUES y boton para rotar Normal -> Detallado -> Diagnostico.
    - Deteccion generica de cualquier version instalada desde el build del motor.
    - Identidad de marca SQL PRIME en ventana, cabecera, informes y log.
    - Exportacion continua a SQL_PRIME.log con boton de lectura.
    - Correcciones: variable $args (reservada), timer con handlers duplicados,
      nombre de archivo esperado y manejo de errores.
#>

#requires -Version 5.1

# ==============================================================================
# 1. AUTO-ELEVACIÓN A ADMINISTRADOR
# ==============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $q = [char]34
    $cliPass = if ($args -and $args.Count) { ' ' + (($args | ForEach-Object { $q + $_ + $q }) -join ' ') } else { '' }
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $q$PSCommandPath$q$cliPass" -Verb RunAs
    Exit
}

# ------------------------------------------------------------------------------
# Cerrar instancias antiguas de esta misma herramienta. Si se vuelve a abrir
# la app mientras la version anterior sigue en memoria, el timer viejo sigue
# logueando "No se puede enlazar el argumento al parametro Job porque es null".
# Se excluye el proceso actual y su padre (la consola que lanzo el script).
# ------------------------------------------------------------------------------
try {
    $scriptName = [System.IO.Path]::GetFileName($PSCommandPath)
    if ($scriptName) {
        $parentPid = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction SilentlyContinue).ParentProcessId
        $stale = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -in @('powershell.exe', 'pwsh.exe') -and
            $_.ProcessId -ne $PID -and
            $_.ProcessId -ne $parentPid -and
            $_.CommandLine -and
            $_.CommandLine -like "*$scriptName*"
        })
        # Fallback: si WMI no expone la linea de comandos (procesos elevados),
        # se buscan ventanas WPF de PowerShell/PowerShell 7 distintas de esta.
        $byWindow = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ProcessName -in @('powershell', 'pwsh') -and
            $_.Id -ne $PID -and
            $_.Id -ne $parentPid -and
            $_.MainWindowHandle -ne 0 -and
            $_.StartTime -lt (Get-Date).AddMinutes(-1)
        })
        $ids = @($stale | ForEach-Object { $_.ProcessId }) + @($byWindow | ForEach-Object { $_.Id }) | Select-Object -Unique
        foreach ($id in $ids) {
            Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        }
        if ($ids.Count -gt 0) {
            Write-Host "Se cerraron $($ids.Count) instancia(s) antigua(s) de la herramienta." -ForegroundColor Yellow
        }
    }
} catch { }

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Modo CLI (automatizacion): -StartAll | -StopAll | -Verify | -Report
$script:CliAction = $null
foreach ($a in @($args)) {
    if ($a -in @('-StartAll','-StopAll','-Verify','-Report')) { $script:CliAction = $a.TrimStart('-') }
}

# ==============================================================================
# 2. GESTIÓN DE CONFIGURACIÓN
# ==============================================================================
$ConfigPath = Join-Path $PSScriptRoot "ui_config.json"
$script:CurrentTheme = "Auto" # Dark, Light, Auto

# Log persistente de todas las acciones de la app (se exporta a .log).
$script:LogPath = Join-Path $PSScriptRoot "SQL_PRIME.log"
# Migración única: conservar el historial del log anterior al cambiar de marca.
$script:LegacyLogPath = Join-Path $PSScriptRoot "Fix_Error-0x800706be.log"
if (-not (Test-Path -LiteralPath $script:LogPath) -and (Test-Path -LiteralPath $script:LegacyLogPath)) {
    try { Copy-Item -LiteralPath $script:LegacyLogPath -Destination $script:LogPath -Force -ErrorAction Stop } catch { }
}
$script:LogUtf8 = New-Object System.Text.UTF8Encoding($false)
$script:LastLogEntry = ""
$script:LastLogTime = [datetime]::MinValue
$script:DownloadWarningShown = $false
try {
    $header = "`r`n===== SESIÓN $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =====`r`n"
    [System.IO.File]::AppendAllText($script:LogPath, $header, $script:LogUtf8)
} catch { }

if (Test-Path $ConfigPath) {
    try {
        $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        if ($cfg.Theme) { $script:CurrentTheme = $cfg.Theme }
    } catch {}
}

function Save-Config {
    $cfg = @{ Theme = $script:CurrentTheme }
    $cfg | ConvertTo-Json | Out-File -FilePath $ConfigPath -Encoding utf8 -Force
}

# Módulos Fase 0 (fundación): config, logging estructurado, integridad, errores, Authenticode.
$script:Phase0Modules = @('modules\Config.ps1','modules\Logging.ps1','modules\Integrity.ps1','modules\ErrorHandling.ps1','modules\Authenticode.ps1','modules\Catalog.ps1','modules\Inventory.ps1','modules\Services.ps1','modules\Detection.ps1','modules\Download.ps1','modules\Wizard.ps1','modules\I18n.ps1','modules\DesignSystem.ps1','modules\DownloadQueue.ps1')
foreach ($m in $script:Phase0Modules) {
    $mp = Join-Path $PSScriptRoot $m
    if (Test-Path -LiteralPath $mp) {
        try { . $mp } catch { Write-Warning "No se pudo cargar ${m}: $($_.Exception.Message)" }
    }
}
try { $null = Get-SQLPrimeConfig -BaseDir $PSScriptRoot; Initialize-SQLPrimeLogging -BaseDir (Join-Path $PSScriptRoot 'modules') } catch { }
$script:KnownHashes = @{}
$script:DownloadOperationId = '' 

# Modulo con TODAS las mejoras avanzadas (Bloques A-F). Se carga antes de la GUI
# para que sus funciones ya existan cuando se enlacen los eventos de los botones.
$script:EnhancementsPath = Join-Path $PSScriptRoot "SQL_PRIME_Enhancements.ps1"
if (Test-Path -LiteralPath $script:EnhancementsPath) {
    try { . $script:EnhancementsPath; Initialize-SQLPrimeOptions }
    catch { Write-Warning "No se pudo cargar SQL_PRIME_Enhancements.ps1: $($_.Exception.Message)" }
}

# ------------------------------------------------------------------------------
# Catálogo de Service Packs y rutas oficiales de descarga (verificado en Microsoft)
# Nota: los SP son acumulativos; SP4 (10.0) y SP3 (10.50) son los últimos.
# ------------------------------------------------------------------------------
# Definiciones de SP/KB/tamaños movidas a modules/Catalog.ps1 (Fase 0).

# ------------------------------------------------------------------------------
# CATÁLOGO MULTIVERSIÓN DE SQL SERVER (6.5 -> 2025)
# Incluye todas las generaciones, sus Service Packs (o CU/GDR cuando no hay SP),
# arquitecturas, estado de soporte y enlaces oficiales. Se usa para generar la
# estructura de carpetas y para el informe profesional del botón CATÁLOGO.
# ------------------------------------------------------------------------------
$script:SQLVersionCatalog = @(
    [pscustomobject]@{ Key="6.5"; Name="SQL Server 6.5"; Folder="SQL Server 6.5 (1996)"; Build="6.5"; Archs=@("x86"); Status="Fin de soporte (2003)";
        SPs=@(@{Label="SP6a"; KB=""}); Note="Primera generación. Solo x86. Los instaladores originales ya no están en Download Center; usar Microsoft Update Catalog / archivo."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+6.5+SP6a"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%206.5" },
    [pscustomobject]@{ Key="7.0"; Name="SQL Server 7.0"; Folder="SQL Server 7.0 (1998)"; Build="7.0"; Archs=@("x86"); Status="Fin de soporte (2008)";
        SPs=@(@{Label="SP4"; KB=""}); Note="Solo x86. Último Service Pack SP4."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+7.0+SP4"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%207.0" },
    [pscustomobject]@{ Key="8.0"; Name="SQL Server 2000"; Folder="SQL Server 2000 (8.0)"; Build="8.0"; Archs=@("x86","ia64"); Status="Fin de soporte (2013)";
        SPs=@(@{Label="SP4"; KB=""}); Note="Solo x86/IA64. SP4 es la última actualización."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+2000+SP4"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202000" },
    [pscustomobject]@{ Key="9.0"; Name="SQL Server 2005"; Folder="SQL Server 2005 (9.0)"; Build="9.0"; Archs=@("x86","x64","ia64"); Status="Fin de soporte (2016)";
        SPs=@(@{Label="SP4"; KB="2463332"},@{Label="SP3"; KB="955706"},@{Label="SP2"; KB="937792"},@{Label="SP1"; KB="916218"}); Note="SP4 acumulativo (KB2463332)."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2463332"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202005" },
    [pscustomobject]@{ Key="10.0"; Name="SQL Server 2008"; Folder="SQL Server 2008 (10.0)"; Build="10.0"; Archs=@("x86","x64","ia64"); Status="Fin de soporte (2019)";
        SPs=@(@{Label="SP4"; KB="2979596"},@{Label="SP3"; KB="2546951"},@{Label="SP2"; KB="2285068"},@{Label="SP1"; KB="968369"}); Note="SP4 acumulativo (KB2979596). Descarga directa ENU/ESN automatizada en esta herramienta."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2979596"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202008" },
    [pscustomobject]@{ Key="10.50"; Name="SQL Server 2008 R2"; Folder="SQL Server 2008 R2 (10.50)"; Build="10.50"; Archs=@("x64","ia64"); Status="Fin de soporte (2019)";
        SPs=@(@{Label="SP3"; KB="2979597"},@{Label="SP2"; KB="2630458"},@{Label="SP1"; KB="2528583"}); Note="SP3 acumulativo (KB2979597). Ojo con rama QFE/CU 10.52.x frente a GDR 10.50.x."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2979597"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202008%20R2" },
    [pscustomobject]@{ Key="11.0"; Name="SQL Server 2012"; Folder="SQL Server 2012 (11.0)"; Build="11.0"; Archs=@("x86","x64"); Status="Fin de soporte (2024)";
        SPs=@(@{Label="SP4"; KB="2976987"},@{Label="SP3"; KB="2755531"},@{Label="SP2"; KB="2692828"},@{Label="SP1"; KB="2679368"}); Note="SP4 acumulativo (KB2976987)."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2976987"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202012" },
    [pscustomobject]@{ Key="12.0"; Name="SQL Server 2014"; Folder="SQL Server 2014 (12.0)"; Build="12.0"; Archs=@("x86","x64"); Status="Fin de soporte (2024)";
        SPs=@(@{Label="SP3"; KB="3072779"},@{Label="SP2"; KB="2967540"},@{Label="SP1"; KB="2931693"}); Note="SP3 acumulativo (KB3072779)."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=3072779"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202014" },
    [pscustomobject]@{ Key="13.0"; Name="SQL Server 2016"; Folder="SQL Server 2016 (13.0)"; Build="13.0"; Archs=@("x86","x64"); Status="Soporte ampliado (hasta 2026)";
        SPs=@(@{Label="SP3"; KB=""},@{Label="SP2"; KB="4052357"},@{Label="SP1"; KB="3182545"}); Note="SP3 es el último Service Pack. Después solo CU/GDR."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+2016+SP3"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202016" },
    [pscustomobject]@{ Key="14.0"; Name="SQL Server 2017"; Folder="SQL Server 2017 (14.0)"; Build="14.0"; Archs=@("x64"); Status="Soporte principal / ampliado";
        SPs=@(@{Label="CU (sin Service Pack)"; KB=""}); Note="No hay Service Packs: se actualiza con Cumulative Updates (CU) y GDR. Instalar siempre la CU más reciente."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+2017+CU"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202017" },
    [pscustomobject]@{ Key="15.0"; Name="SQL Server 2019"; Folder="SQL Server 2019 (15.0)"; Build="15.0"; Archs=@("x64"); Status="Soporte principal / ampliado";
        SPs=@(@{Label="CU (sin Service Pack)"; KB=""}); Note="No hay Service Packs: usar la CU más reciente publicada en Microsoft Update Catalog."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+2019+CU"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202019" },
    [pscustomobject]@{ Key="16.0"; Name="SQL Server 2022"; Folder="SQL Server 2022 (16.0)"; Build="16.0"; Archs=@("x64"); Status="Soporte principal / ampliado";
        SPs=@(@{Label="CU (sin Service Pack)"; KB=""}); Note="No hay Service Packs: usar la CU más reciente. Compatible con Azure Arc y TDE ledger."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+2022+CU"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202022" },
    [pscustomobject]@{ Key="17.0"; Name="SQL Server 2025"; Folder="SQL Server 2025 (17.0)"; Build="17.0"; Archs=@("x64"); Status="Versión más reciente";
        SPs=@(@{Label="CU (sin Service Pack)"; KB=""}); Note="Última generación. Sin Service Packs; actualizaciones acumulativas y soporte para IA/vector search."; Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=SQL+Server+2025+CU"; Lifecycle="https://learn.microsoft.com/lifecycle/products/?terms=SQL%20Server%202025" }
)

function Get-VersionDefinition {
    param([string]$Key)
    return ($script:SQLVersionCatalog | Where-Object { $_.Key -eq $Key } | Select-Object -First 1)
}

# Mapeo de build de motor -> versión, SP y nombre comercial (detección genérica).
$script:SQLBuildMap = @(
    @{ Prefix="6.5";  Name="SQL Server 6.5";     SPs=@() },
    @{ Prefix="7.0";  Name="SQL Server 7.0";     SPs=@() },
    @{ Prefix="8.0";  Name="SQL Server 2000";    SPs=@() },
    @{ Prefix="9.0";  Name="SQL Server 2005";    SPs=@(@{Min=5000;Label="SP4"},@{Min=4000;Label="SP3"},@{Min=3000;Label="SP2"},@{Min=2000;Label="SP1"}) },
    @{ Prefix="10.0"; Name="SQL Server 2008";    SPs=@(@{Min=6000;Label="SP4"},@{Min=5500;Label="SP3"},@{Min=4000;Label="SP2"},@{Min=2500;Label="SP1"}) },
    @{ Prefix="10.50";Name="SQL Server 2008 R2"; SPs=@(@{Min=6000;Label="SP3"},@{Min=4000;Label="SP2"},@{Min=2500;Label="SP1"}) },
    @{ Prefix="11.0"; Name="SQL Server 2012";    SPs=@(@{Min=7000;Label="SP4"},@{Min=6000;Label="SP3"},@{Min=5000;Label="SP2"},@{Min=3000;Label="SP1"}) },
    @{ Prefix="12.0"; Name="SQL Server 2014";    SPs=@(@{Min=6200;Label="SP3"},@{Min=5200;Label="SP2"},@{Min=4100;Label="SP1"}) },
    @{ Prefix="13.0"; Name="SQL Server 2016";    SPs=@(@{Min=6300;Label="SP3"},@{Min=5000;Label="SP2"},@{Min=4000;Label="SP1"}) },
    @{ Prefix="14.0"; Name="SQL Server 2017";    SPs=@(@{Min=3000;Label="CU/GDR"},@{Min=0;Label="RTM"}) },
    @{ Prefix="15.0"; Name="SQL Server 2019";    SPs=@(@{Min=4000;Label="CU/GDR"},@{Min=0;Label="RTM"}) },
    @{ Prefix="16.0"; Name="SQL Server 2022";    SPs=@(@{Min=1000;Label="CU/GDR"},@{Min=0;Label="RTM"}) },
    @{ Prefix="17.0"; Name="SQL Server 2025";    SPs=@(@{Min=1000;Label="CU/GDR"},@{Min=0;Label="RTM"}) }
)

function Get-SafeFolderName {
    param([string]$Name)
    return (($Name -replace '[\\/:*?"<>|]', '_').Trim())
}

# Crea la estructura profesional de carpetas para una o todas las versiones.
function New-SQLVersionFolders {
    param([string[]]$Keys, [string]$BaseDir = $PSScriptRoot)

    $created = 0
    $reportLines = @()
    $reportLines += "SQL PRIME - CATÁLOGO MULTIVERSIÓN DE SQL SERVER"
    $reportLines += "Estructura de actualizaciones y reparaciones · De SQL Server 6.5 a 2025"
    $reportLines += "Diagnostica. Repara. Actualiza."
    $reportLines += "Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $reportLines += "Raíz: $BaseDir"
    $reportLines += ("=" * 100)

    foreach ($key in $Keys) {
        $v = Get-VersionDefinition -Key $key
        if (-not $v) {
            Update-UI -Log "Versión desconocida: $key" -LogColor "#FF0000"
            continue
        }
        $installersRoot = Join-Path $BaseDir "Instaladores"
        if (-not (Test-Path -LiteralPath $installersRoot)) { New-Item -ItemType Directory -Path $installersRoot -Force | Out-Null }
        $vRoot = Join-Path $installersRoot (Get-SafeFolderName $v.Folder)
        $archs = @($v.Archs)
        $langs = @("ENU", "ESN")

        $dirs = New-Object System.Collections.Generic.List[string]
        $dirs.Add("_DOCUMENTACION")
        $dirs.Add("_REPARACIONES\Errores_comunes")
        $dirs.Add("_REPARACIONES\Scripts")
        $dirs.Add("_HERRAMIENTAS")
        $dirs.Add("_LOGS")
        $dirs.Add("RTM")
        $dirs.Add("CumulativeUpdates")
        $dirs.Add("SecurityFixes")
        foreach ($sp in $v.SPs) {
            $dirs.Add("ServicePacks\$(Get-SafeFolderName $sp.Label)")
        }
        foreach ($arch in $archs) {
            foreach ($lang in $langs) {
                $dirs.Add("RTM\$arch\$lang")
                $dirs.Add("CumulativeUpdates\$arch\$lang")
                $dirs.Add("SecurityFixes\$arch\$lang")
                foreach ($sp in $v.SPs) {
                    $dirs.Add("ServicePacks\$(Get-SafeFolderName $sp.Label)\$arch\$lang")
                }
            }
        }

        foreach ($rel in $dirs) {
            $full = Join-Path $vRoot $rel
            if (-not (Test-Path -LiteralPath $full)) {
                New-Item -ItemType Directory -Path $full -Force | Out-Null
                $created++
            }
        }

        # Ficha informativa de la versión dentro de su carpeta.
        $readme = @()
        $readme += "SQL PRIME | SQL SERVER: $($v.Name)"
        $readme += "Build principal: $($v.Build)"
        $readme += "Estado de soporte: $($v.Status)"
        $readme += "Arquitecturas: $($archs -join ', ')"
        $readme += "Idiomas previstos: $($langs -join ', ')"
        $readme += ""
        $readme += "SERVICE PACKS / ACTUALIZACIONES:"
        foreach ($sp in $v.SPs) {
            $kbText = if ($sp.KB) { " (KB$($sp.KB))" } else { "" }
            $readme += "  - $($sp.Label)$kbText"
        }
        $readme += ""
        $readme += "NOTA: $($v.Note)"
        $readme += ""
        $readme += "ENLACES OFICIALES:"
        $readme += "  Catálogo Microsoft Update : $($v.Catalog)"
        $readme += "  Ciclo de vida             : $($v.Lifecycle)"
        $readme += "  Documentación             : https://learn.microsoft.com/en-us/sql/sql-server/"
        $readme += ""
        $readme += "ESTRUCTURA:"
        $readme += "  RTM\                  Instalador original (sin service pack)"
        $readme += "  ServicePacks\         Service Packs acumulativos por arquitectura e idioma"
        $readme += "  CumulativeUpdates\    CU/GDR para versiones sin Service Packs"
        $readme += "  SecurityFixes\        Parches de seguridad independientes"
        $readme += "  _REPARACIONES\        Scripts y diagnosticos de errores"
        $readme += "  _LOGS\                Logs exportados por la herramienta"
        $readme += "  _DOCUMENTACION\       Fichas, KBs y enlaces oficiales"
        $readme += ""
        $readme += "RECOMENDACIÓN: instalar siempre el Service Pack/CU más alto disponible."
        $readme += "Los SP son acumulativos: no hace falta instalar los anteriores."
        $readmePath = Join-Path $vRoot "_DOCUMENTACION\LEEME_$($v.Key -replace '\.','_').txt"
        [System.IO.File]::WriteAllText($readmePath, (($readme -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))

        $reportLines += ""
        $reportLines += ">>> $($v.Name) [$($v.Key)]  -  $($v.Status)"
        $reportLines += "    Ruta: $vRoot"
        $reportLines += "    Arquitecturas: $($archs -join ', ') | Idiomas: $($langs -join ', ')"
        foreach ($sp in $v.SPs) {
            $kbText = if ($sp.KB) { " KB$($sp.KB)" } else { "" }
            $reportLines += "      • $($sp.Label)$kbText"
        }
        $reportLines += "    Catálogo: $($v.Catalog)"
        $reportLines += "    Nota: $($v.Note)"
        Update-UI -Log "Estructura lista: $($v.Name) -> $vRoot" -LogColor "#00FF00"
    }

    $reportPath = Join-Path $BaseDir "Catalogo_Multiversion_SQL.txt"
    [System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    Update-UI -Log "Informe del catálogo: $reportPath" -LogColor "#00CCFF"
    Update-UI -Log "Total carpetas creadas: $created" -LogColor "#00FF00"
    return $created
}

# Muestra/exporta el catálogo completo y abre los sitios oficiales de la versión elegida.
function Show-VersionCatalog {
    param([string]$Key)

    $reportPath = Join-Path $PSScriptRoot "Catalogo_Multiversion_SQL.txt"
    if (-not (Test-Path -LiteralPath $reportPath)) {
        $null = New-SQLVersionFolders -Keys @($script:SQLVersionCatalog.Key) -BaseDir $PSScriptRoot | Out-Null
    }
    if (Test-Path -LiteralPath $reportPath) {
        Start-Process notepad.exe -ArgumentList "`"$reportPath`""
        Update-UI -Log "Catálogo abierto: $reportPath" -LogColor "#00CCFF"
    }

    if ($Key -and $Key -ne "ALL") {
        $v = Get-VersionDefinition -Key $Key
        if ($v) {
            Start-Process "$($v.Catalog)"
            Start-Process "$($v.Lifecycle)"
            Update-UI -Log "Sitos oficiales abiertos para $($v.Name): catálogo y ciclo de vida." -LogColor "#00FF00"
        }
    }
}

# Funciones de catálogo/idioma movidas a modules/Catalog.ps1 (Fase 0).

# ==============================================================================
# 3. XAML (INTERFAZ GRÁFICA)
# ==============================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SQL PRIME | Repair &amp; Update Center - Multiversión" Height="880" Width="1040"
        MinWidth="700" MinHeight="560"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip"
        FontFamily="Segoe UI, Segoe UI Emoji">

    <Window.Resources>
        <!-- Brushes dinámicos: Apply-Theme cambia su Color según el tema activo -->
        <SolidColorBrush x:Key="HoverBg" Color="#2A2A3D"/>
        <SolidColorBrush x:Key="HoverFg" Color="#00FFFF"/>
        <SolidColorBrush x:Key="PressedBg" Color="#3A3A52"/>
        <SolidColorBrush x:Key="CloseHoverBg" Color="#C42B1C"/>
        <SolidColorBrush x:Key="CloseHoverFg" Color="#FFFFFF"/>
        <SolidColorBrush x:Key="ItemHoverBg" Color="#233A4A"/>
        <SolidColorBrush x:Key="ItemHoverFg" Color="#00FFFF"/>
        <SolidColorBrush x:Key="ItemSelectedBg" Color="#173A4A"/>
        <SolidColorBrush x:Key="ItemSelectedFg" Color="#00FFFF"/>

        <!-- Barra de progreso futurista: Apply-Theme ajusta los 3 stops según Dark/Light.
             Se usa con DynamicResource para que el cambio de tema repinte el relleno. -->
        <LinearGradientBrush x:Key="ProgressFillBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#00F5FF" Offset="0"/>
            <GradientStop Color="#7C4DFF" Offset="0.5"/>
            <GradientStop Color="#FF3DFF" Offset="1"/>
        </LinearGradientBrush>

        <!-- Botón de tema: hover con fondo redondeado y letra de acento -->
        <Style x:Key="TitleBarButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="HorizontalContentAlignment" Value="Center"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6" SnapsToDevicePixels="True">
                            <ContentPresenter x:Name="Cp" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource HoverBg}"/>
                                <Setter TargetName="Cp" Property="TextElement.Foreground" Value="{DynamicResource HoverFg}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource PressedBg}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botón MINIMIZAR: hover con fondo diferente -->
        <Style x:Key="TitleBarMinStyle" TargetType="Button" BasedOn="{StaticResource TitleBarButtonStyle}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6" SnapsToDevicePixels="True">
                            <ContentPresenter x:Name="Cp" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource MinimizeHoverBg}"/>
                                <Setter TargetName="Cp" Property="TextElement.Foreground" Value="{DynamicResource HoverFg}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#4455AA"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botón CERRAR: hover rojo, mismo comportamiento de arrastre protegido -->
        <Style x:Key="TitleBarCloseStyle" TargetType="Button" BasedOn="{StaticResource TitleBarButtonStyle}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6" SnapsToDevicePixels="True">
                            <ContentPresenter x:Name="Cp" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource CloseHoverBg}"/>
                                <Setter TargetName="Cp" Property="TextElement.Foreground" Value="{DynamicResource CloseHoverFg}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#8B1A10"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Listado de versiones: al pasar el puntero cambian fondo Y color de letra -->
        <Style x:Key="VersionItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="3" SnapsToDevicePixels="True">
                            <ContentPresenter x:Name="Cp" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ItemHoverBg}"/>
                                <Setter TargetName="Cp" Property="TextElement.Foreground" Value="{DynamicResource ItemHoverFg}"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ItemSelectedBg}"/>
                                <Setter TargetName="Cp" Property="TextElement.Foreground" Value="{DynamicResource ItemSelectedFg}"/>
                                <Setter Property="FontWeight" Value="Bold"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Border x:Name="MainBorder" BorderThickness="2" CornerRadius="12" Background="#0D0D14">
        <Border.Effect><DropShadowEffect x:Name="MainShadow" Color="#00FFFF" BlurRadius="20" ShadowDepth="0" Opacity="0.6"/></Border.Effect>
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="45"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- Barra de Título (fija) -->
            <Border x:Name="TitleBar" Grid.Row="0" Background="#11111A" CornerRadius="12,12,0,0">
                <Grid>
                    <TextBlock x:Name="TxtTitle" Text="⚡ SQL PRIME - REPAIR &amp; UPDATE CENTER" Foreground="#00FFFF" FontWeight="Bold" FontSize="13" VerticalAlignment="Center" Margin="15,0,0,0" TextTrimming="CharacterEllipsis"/>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="BtnTheme" Style="{StaticResource TitleBarButtonStyle}" Content="🎨 AUTO" Foreground="#FFFFFF" Background="Transparent" BorderThickness="0" Height="45" MinWidth="120" Margin="0,0,6,0" Cursor="Hand" FontSize="12" FontWeight="Bold" ToolTip="Cambiar tema: Oscuro / Claro / Auto"/>
                        <Button x:Name="BtnMinimize" Style="{StaticResource TitleBarButtonStyle}" Content="&#x2212;" Foreground="White" Background="Transparent" BorderThickness="0" Width="45" Height="45" Cursor="Hand" FontSize="16" FontWeight="Bold" ToolTip="Minimizar"/>
                        <Button x:Name="BtnClose" Style="{StaticResource TitleBarCloseStyle}" Content="✕" Foreground="White" Background="Transparent" BorderThickness="0" Width="45" Height="45" Cursor="Hand" FontSize="16" ToolTip="Cerrar herramienta"/>
                    </StackPanel>
                </Grid>
            </Border>

            <!-- Contenido fijo: solo el log tiene desplazamiento interno -->
            <Grid x:Name="ContentGrid" Grid.Row="1" VerticalAlignment="Stretch">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*" MinHeight="100"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                    <!-- Cabecera -->
                    <StackPanel Grid.Row="0" Margin="25,18,25,8">
                        <TextBlock x:Name="TxtMainHeader" Text="SQL PRIME · CENTRO DE REPARACIÓN Y ACTUALIZACIÓN" Foreground="#FF00FF" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center">
                            <TextBlock.Effect><DropShadowEffect x:Name="HeaderShadow" Color="#FF00FF" BlurRadius="12" ShadowDepth="0"/></TextBlock.Effect>
                        </TextBlock>
                        <TextBlock x:Name="TxtSubHeader" Text="De SQL Server 6.5 a 2025 · Service Packs, CU, reparaciones y estructura profesional de carpetas" Foreground="#8888AA" FontSize="13" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center" Margin="0,5,0,0"/>
                    </StackPanel>

                    <!-- Paneles de Información -->
                    <Grid Grid.Row="1" Margin="25,8,25,8">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="1*"/><ColumnDefinition Width="1*"/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name="PanelStatus" Grid.Column="0" Background="#1A1A2A" Margin="0,0,8,0" Padding="15" CornerRadius="8" BorderBrush="#333355" BorderThickness="1">
                            <StackPanel>
                                <TextBlock x:Name="TxtStatusTitle" Text="🖥️ ESTADO DEL SISTEMA" Foreground="#00CCFF" FontWeight="Bold" FontSize="13" Margin="0,0,0,8"/>
                                <TextBlock x:Name="TxtVersion" Text="Versión: Detectando..." Foreground="#CCCCDD" FontSize="13" Margin="0,0,0,4" TextWrapping="Wrap"/>
                                <TextBlock x:Name="TxtEdition" Text="Edición: Detectando..." Foreground="#CCCCDD" FontSize="13" Margin="0,0,0,4" TextWrapping="Wrap"/>
                                <TextBlock x:Name="TxtLanguage" Text="Idioma: Detectando..." Foreground="#CCCCDD" FontSize="13" Margin="0,0,0,4" TextWrapping="Wrap"/>
                                <TextBlock x:Name="TxtArch" Text="Arquitectura: Detectando..." Foreground="#CCCCDD" FontSize="13" TextWrapping="Wrap"/>
                                <WrapPanel x:Name="ServiceLights" Margin="0,8,0,0" ToolTip="Semáforo de servicios SQL (🟢 activo / 🟡 detenido / 🔴 desactivado)"/>
                            </StackPanel>
                        </Border>
                        <Border x:Name="PanelUpdate" Grid.Column="1" Background="#1A1A2A" Margin="8,0,0,0" Padding="15" CornerRadius="8" BorderBrush="#333355" BorderThickness="1">
                            <StackPanel>
                                <TextBlock x:Name="TxtUpdateTitle" Text="📦 ACTUALIZACIÓN DISPONIBLE" Foreground="#FFAA00" FontWeight="Bold" FontSize="13" Margin="0,0,0,8"/>
                                <TextBlock x:Name="TxtUpdate" Text="Analizando instaladores..." Foreground="#FFD700" FontSize="13" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <!-- Barra de Progreso -->
                    <StackPanel Grid.Row="3" Margin="25,4,25,4">
                        <Grid>
                            <ProgressBar x:Name="ProgressBar" Height="24" Value="0" Maximum="100" Background="#11111A" BorderThickness="0" Foreground="#00FFFF">
                                <ProgressBar.Template>
                                    <ControlTemplate TargetType="ProgressBar">
                                        <Border Background="{TemplateBinding Background}" CornerRadius="12" BorderBrush="#2A2A45" BorderThickness="1">
                                            <Grid>
                                                <Border x:Name="PART_Indicator" CornerRadius="12" HorizontalAlignment="Left" Background="{DynamicResource ProgressFillBrush}">
                                                    <Border.Effect><DropShadowEffect Color="#8B5CF6" BlurRadius="12" ShadowDepth="0" Opacity="0.65"/></Border.Effect>
                                                    <!-- Brillo superior para dar profundidad "HUD" al relleno -->
                                                    <Border Opacity="0.22" CornerRadius="12" IsHitTestVisible="False">
                                                        <Border.Background>
                                                            <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                                                                <GradientStop Color="#FFFFFF" Offset="0"/>
                                                                <GradientStop Color="#000000" Offset="1"/>
                                                            </LinearGradientBrush>
                                                        </Border.Background>
                                                    </Border>
                                                </Border>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ProgressBar.Template>
                            </ProgressBar>
                            <TextBlock x:Name="TxtProgress" Text="0%" Foreground="#FFFFFF" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="12">
                                <TextBlock.Effect><DropShadowEffect Color="#000000" BlurRadius="2" ShadowDepth="0" Opacity="0.85"/></TextBlock.Effect>
                            </TextBlock>
                        </Grid>
                        <TextBlock x:Name="TxtDownloadStatus" Text="" Foreground="#00CCFF" FontSize="11" Margin="4,3,4,0" TextWrapping="Wrap" Visibility="Collapsed"/>
                    </StackPanel>

                    <!-- Log de Eventos (directamente bajo el estado del sistema) -->
                    <Border x:Name="PanelLog" Grid.Row="2" Margin="25,6,25,6" Background="#08080C" CornerRadius="8" BorderBrush="#00AAAA" BorderThickness="1">
                        <Grid>
                            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                            <TextBox x:Name="TxtLogFilter" Height="26" Margin="6,4,6,2" Background="#11111A" Foreground="#FFFFFF" BorderBrush="#333355" FontSize="11" VerticalContentAlignment="Center" ToolTip="Filtrar el log por texto (se aplica al escribir)"/>
                            <ScrollViewer x:Name="ScrollLog" Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="10">
                                <RichTextBox x:Name="TxtLog" Background="Transparent" Foreground="#00FFCC" FontFamily="Consolas, Courier New" FontSize="12" BorderThickness="0" IsReadOnly="True"/>
                            </ScrollViewer>
                        </Grid>
                    </Border>

                    <!-- Botones de Acción (se envuelven segun el ancho) -->
                    <TabControl x:Name="ActionTabs" Grid.Row="4" Margin="15,4,15,14" Background="#14141F" BorderBrush="#333355"
                                Foreground="#FFFFFF" FontSize="11" HorizontalAlignment="Stretch">
                        <TabItem Header="🔧 DIAGNÓSTICO Y SERVICIOS">
                        <WrapPanel HorizontalAlignment="Center" Margin="0,6,0,6">
                            <Button x:Name="BtnRefresh" Content="🔄 REFRESCAR ESTADO" Background="#FFAA00" Foreground="#000000" FontWeight="Bold" Width="150" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Volver a detectar instancia, versión, SP e idioma de SQL Server">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnRepairWMI" Content="🛠️ REPARAR WMI" Background="#00FFFF" Foreground="#000000" FontWeight="Bold" Width="150" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Reparar el proveedor WMI (error 0x800706be)">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnUpdate" Content="🚀 ACTUALIZAR SP" Background="#FF00FF" Foreground="#FFFFFF" FontWeight="Bold" Width="170" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Instalar el Service Pack recomendado para la versión detectada">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnService" Content="🔧 REPARAR SERVICIOS SQL" Background="#FF8800" Foreground="#FFFFFF" FontWeight="Bold" Width="190" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Reparar, iniciar y verificar TODOS los servicios SQL instalados">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnStopAllServices" Content="⛔ DESACTIVAR SERVICIOS" Background="#8B1A1A" Foreground="#FFFFFF" FontWeight="Bold" Width="190" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Detener y desactivar TODOS los servicios SQL instalados (se pueden reactivar con Reparar Servicios)">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                        </WrapPanel>
                        </TabItem>
                        <TabItem Header="📦 ACTUALIZACIÓN Y DESCARGAS">
                        <WrapPanel HorizontalAlignment="Center" Margin="0,6,0,6">
                            <Button x:Name="BtnInventory" Content="📋 INVENTARIO / DESCARGAS" Background="#00AA88" Foreground="#FFFFFF" FontWeight="Bold" Width="200" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Analizar los instaladores disponibles y su ubicación">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnDownload" Content="⬇ DESCARGAR FALTANTES" Background="#0088CC" Foreground="#FFFFFF" FontWeight="Bold" Width="195" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Descargar los paquetes faltantes (reanuda descargas parciales)">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnStopDownload" Content="⏹ DETENER" Background="#CC3333" Foreground="#FFFFFF" FontWeight="Bold" Width="150" Height="42" Margin="4" Cursor="Hand" FontSize="11" IsEnabled="False" ToolTip="Detener la descarga actual y conservar el fichero .part" AutomationProperties.Name="Detener todas las descargas" AutomationProperties.HelpText="Conserva los ficheros parciales para reanudar después">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnPauseFile" Content="⏸ PAUSAR ARCHIVO" Background="#AA6600" Foreground="#FFFFFF" FontWeight="Bold" Width="165" Height="42" Margin="4" Cursor="Hand" FontSize="11" IsEnabled="False" ToolTip="Pausa el archivo actual (o el siguiente de la cola) conservando el .part" AutomationProperties.Name="Pausar archivo actual" AutomationProperties.HelpText="Marca el archivo actual como pausado en la cola persistente">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnResumeFile" Content="▶ REANUDAR ARCHIVO" Background="#0088AA" Foreground="#FFFFFF" FontWeight="Bold" Width="170" Height="42" Margin="4" Cursor="Hand" FontSize="11" IsEnabled="False" ToolTip="Reanuda el archivo pausado desde el último byte guardado" AutomationProperties.Name="Reanudar archivo pausado" AutomationProperties.HelpText="Cambia el estado del archivo a Pending para continuar desde .part">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnRestart" Content="🔄 REINICIAR PC" Background="#FF3333" Foreground="#FFFFFF" FontWeight="Bold" Width="130" Height="42" Margin="4" Cursor="Hand" FontSize="11" IsEnabled="False" ToolTip="Reiniciar el equipo (se habilita tras una actualización)">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnLog" Content="📄 VER LOG .log" Background="#666666" Foreground="#FFFFFF" FontWeight="Bold" Width="140" Height="42" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Abrir SQL_PRIME.log con el historial completo">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                        </WrapPanel>
                        </TabItem>
                        <TabItem Header="🎯 VERSIONES Y CARPETAS">
                        <WrapPanel HorizontalAlignment="Center" Margin="0,6,0,6">
                            <TextBlock x:Name="TxtVersionLabel" Text="🎯 VERSIÓN SQL:" Foreground="#00FFFF" FontWeight="Bold" FontSize="12" VerticalAlignment="Center" Margin="4"/>
                            <ComboBox x:Name="CmbSQLVersion" Width="300" Height="32" VerticalContentAlignment="Center" Margin="4" ItemContainerStyle="{StaticResource VersionItemStyle}" ToolTip="Elige una versión o TODAS para generar toda la estructura"/>
                            <Button x:Name="BtnMakeFolders" Content="📁 CREAR CARPETAS" Background="#00AA88" Foreground="#FFFFFF" FontWeight="Bold" Width="175" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Crear la estructura de carpetas de la versión elegida">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnCatalog" Content="📚 CATÁLOGO / SITIOS" Background="#4455AA" Foreground="#FFFFFF" FontWeight="Bold" Width="175" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Ver el catálogo y los sitios oficiales de descarga">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnOpenRoot" Content="📂 ABRIR CARPETAS" Background="#8866CC" Foreground="#FFFFFF" FontWeight="Bold" Width="150" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Abrir la carpeta raíz de la herramienta">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                        </WrapPanel>
                        </TabItem>
                        <TabItem Header="⚙️ AVANZADO">
                        <WrapPanel HorizontalAlignment="Center" Margin="0,6,0,6">
                            <Button x:Name="BtnManageServices" Content="🎛️ GESTIONAR SERVICIOS" Background="#008899" Foreground="#FFFFFF" FontWeight="Bold" Width="185" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Iniciar/detener servicios individualmente y ver su diagnóstico">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnReport" Content="📊 EXPORTAR INFORME" Background="#5566CC" Foreground="#FFFFFF" FontWeight="Bold" Width="175" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Exportar el estado de servicios antes/después a CSV y HTML">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnProfiles" Content="💾 PERFILES" Background="#8866CC" Foreground="#FFFFFF" FontWeight="Bold" Width="140" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Guardar y aplicar perfiles de estado de servicios">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnSchedule" Content="🕒 PROGRAMAR TAREA" Background="#AA6600" Foreground="#FFFFFF" FontWeight="Bold" Width="170" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Crear una tarea programada diaria que active todos los servicios SQL">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnSimulate" Content="🧪 SIMULACIÓN: OFF" Background="#4455AA" Foreground="#FFFFFF" FontWeight="Bold" Width="170" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Simular las operaciones sin cambiar ningún servicio">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                            <Button x:Name="BtnLogVerbosity" Content="📝 LOG: NORMAL" Background="#2F6F6F" Foreground="#FFFFFF" FontWeight="Bold" Width="170" Height="38" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Rotar el detalle del log: Normal → Detallado (comandos) → Diagnóstico (tiempos)">
                                <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                            </Button>
                        </WrapPanel>
                        </TabItem>
                        <TabItem Header="🧭 ASISTENTE">
                        <StackPanel Margin="12,8,12,8" HorizontalAlignment="Center" Width="720">
                            <TextBlock x:Name="TxtWizardStep" Text="Paso 1/4: Diagnosticar" Foreground="#00F5FF" FontWeight="Bold" FontSize="14" HorizontalAlignment="Center"
                                       AutomationProperties.Name="Paso actual del asistente"/>
                            <TextBlock x:Name="TxtWizardHint" Text="Diagnostica, respalda, aplica y verifica con un flujo guiado." Foreground="#CCCCDD" FontSize="11"
                                       TextWrapping="Wrap" HorizontalAlignment="Center" Margin="0,4,0,8"/>
                            <WrapPanel HorizontalAlignment="Center" Margin="0,2,0,8">
                                <Button x:Name="BtnWizardBack" Content="◀ ATRÁS" Background="#4455AA" Foreground="#FFFFFF" FontWeight="Bold" Width="120" Height="36" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Volver al paso anterior" AutomationProperties.Name="Paso anterior del asistente" IsEnabled="False">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                                </Button>
                                <Button x:Name="BtnWizardNext" Content="SIGUIENTE ▶" Background="#00AA88" Foreground="#FFFFFF" FontWeight="Bold" Width="140" Height="36" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Marcar el paso actual como completado y avanzar" AutomationProperties.Name="Completar paso y avanzar">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                                </Button>
                                <Button x:Name="BtnWizardFail" Content="⚠ MARCAR FALLO" Background="#CC3333" Foreground="#FFFFFF" FontWeight="Bold" Width="140" Height="36" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Registrar el paso actual como fallido y permanecer en él" AutomationProperties.Name="Marcar paso actual como fallido">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                                </Button>
                                <Button x:Name="BtnWizardReset" Content="↺ REINICIAR" Background="#666666" Foreground="#FFFFFF" FontWeight="Bold" Width="130" Height="36" Margin="4" Cursor="Hand" FontSize="11" ToolTip="Reiniciar el asistente desde Diagnosticar" AutomationProperties.Name="Reiniciar asistente">
                                    <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="8"/></Style></Button.Resources>
                                </Button>
                            </WrapPanel>
                            <TextBlock x:Name="TxtWizardHistory" Text="Historial: (vacío)" Foreground="#AAAAAA" FontSize="10" TextWrapping="Wrap"
                                       AutomationProperties.Name="Historial de pasos del asistente"/>
                        </StackPanel>
                        </TabItem>
                    </TabControl>
                </Grid>
        </Grid>
    </Border>
</Window>
"@

# ==============================================================================
# 4. CARGAR VENTANA Y VARIABLES
# ==============================================================================
try {
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    [System.Windows.MessageBox]::Show("Error al cargar interfaz: $_", "Error", "OK", "Error"); Exit
}

# ------------------------------------------------------------------------------
# Modal de progreso para operaciones largas de servicios. Muestra el tiempo
# transcurrido y cada servicio a medida que se procesa, y desactiva TODOS los
# botones de la ventana principal hasta que la tarea termina.
# ------------------------------------------------------------------------------
[xml]$progressXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SQL PRIME - Progreso" Width="540" Height="345"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
        Foreground="#FFFFFF" FontFamily="Segoe UI, Segoe UI Emoji">
    <Window.Resources>
        <!-- Mismo lenguaje visual que la barra principal; el marco cambia con el estado de cada paso. -->
        <LinearGradientBrush x:Key="ModalProgressFillBrush" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#00F5FF" Offset="0"/>
            <GradientStop Color="#7C4DFF" Offset="0.5"/>
            <GradientStop Color="#FF3DFF" Offset="1"/>
        </LinearGradientBrush>
        <SolidColorBrush x:Key="PgbFrameBrush" Color="#00F5FF"/>
    </Window.Resources>
    <Border CornerRadius="10" Background="#14141F" BorderBrush="#00FFFF" BorderThickness="2">
        <Border.Effect><DropShadowEffect Color="#00FFFF" BlurRadius="18" ShadowDepth="0" Opacity="0.7"/></Border.Effect>
        <Grid Margin="16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock x:Name="PgbTitle" Text="PROCESANDO..." Foreground="#00FFFF" FontWeight="Bold" FontSize="15"/>
            <TextBlock x:Name="PgbSubtitle" Grid.Row="1" Text="" Foreground="#8888AA" FontSize="11" Margin="0,4,0,0"/>
            <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,10,0,6">
                <TextBlock x:Name="PgbElapsed" Text="Tiempo: 00:00" Foreground="#FFD700" FontWeight="Bold" FontSize="12"/>
                <TextBlock x:Name="PgbCount" Text="0 / 0" Foreground="#00FFCC" FontWeight="Bold" FontSize="12" Margin="24,0,0,0"/>
                <TextBlock x:Name="PgbEta" Text="Restante: --:--" Foreground="#FFAA00" FontWeight="Bold" FontSize="12" Margin="24,0,0,0"/>
            </StackPanel>
            <Border Grid.Row="3" Background="#08080C" CornerRadius="6" BorderBrush="#333355" BorderThickness="1" Padding="6">
                <ScrollViewer x:Name="PgbScroll" VerticalScrollBarVisibility="Auto">
                    <StackPanel x:Name="PgbItems"/>
                </ScrollViewer>
            </Border>
            <StackPanel Grid.Row="4" Margin="0,10,0,0">
                <Border x:Name="PgbBarFrame" CornerRadius="10" Padding="1" BorderThickness="1" BorderBrush="{DynamicResource PgbFrameBrush}" Background="#11111A">
                    <Grid>
                        <ProgressBar x:Name="PgbBar" Height="16" Minimum="0" Maximum="100" Value="0" Background="#11111A" Foreground="#00FFFF">
                            <ProgressBar.Template>
                                <ControlTemplate TargetType="ProgressBar">
                                    <Border Background="{TemplateBinding Background}" CornerRadius="9">
                                        <Border x:Name="PART_Indicator" CornerRadius="9" HorizontalAlignment="Left" Background="{DynamicResource ModalProgressFillBrush}">
                                            <Border.Effect><DropShadowEffect Color="#8B5CF6" BlurRadius="9" ShadowDepth="0" Opacity="0.7"/></Border.Effect>
                                        </Border>
                                    </Border>
                                </ControlTemplate>
                            </ProgressBar.Template>
                        </ProgressBar>
                        <TextBlock x:Name="PgbPercent" Text="0%" Foreground="#FFFFFF" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="11">
                            <TextBlock.Effect><DropShadowEffect Color="#000000" BlurRadius="2" ShadowDepth="0" Opacity="0.85"/></TextBlock.Effect>
                        </TextBlock>
                    </Grid>
                </Border>
                <Button x:Name="PgbCancel" Content="⏹ CANCELAR OPERACIÓN" Height="30" Margin="0,8,0,0" HorizontalAlignment="Right" Background="#8B1A1A" Foreground="#FFFFFF" FontWeight="Bold" FontSize="11" Cursor="Hand" ToolTip="Detener la operación en curso de forma segura"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

$script:ProgressWindow = $null
$script:ProgressTimer = $null
$script:ProgressStopwatch = $null
$script:ButtonStates = @{}

# Lista explicita: funciona también con botones dentro de pestañas no visibles.
$script:AllButtonNames = @(
    'BtnRefresh','BtnRepairWMI','BtnUpdate','BtnService','BtnStopAllServices',
    'BtnInventory','BtnDownload','BtnStopDownload','BtnPauseFile','BtnResumeFile','BtnRestart','BtnLog',
    'BtnMakeFolders','BtnCatalog','BtnOpenRoot',
    'BtnManageServices','BtnReport','BtnProfiles','BtnSchedule','BtnSimulate','BtnLogVerbosity',
    'BtnWizardBack','BtnWizardNext','BtnWizardFail','BtnWizardReset',
    'BtnTheme','BtnMinimize','BtnClose'
)

function Find-AllButtons {
    param([System.Windows.DependencyObject]$Root)
    $result = @()
    foreach ($name in $script:AllButtonNames) {
        $btn = $window.FindName($name)
        if ($null -ne $btn) { $result += $btn }
    }
    return $result
}

function Set-AllButtonsEnabled {
    param([bool]$Enabled)
    if ($Enabled) {
        foreach ($name in @($script:ButtonStates.Keys)) {
            $btn = $window.FindName($name)
            if ($null -ne $btn) { $btn.IsEnabled = [bool]$script:ButtonStates[$name] }
        }
    } else {
        $script:ButtonStates = @{}
        foreach ($name in $script:AllButtonNames) {
            $btn = $window.FindName($name)
            if ($null -ne $btn) {
                $script:ButtonStates[$name] = $btn.IsEnabled
                $btn.IsEnabled = $false
            }
        }
    }
}

function Pump-UI {
    # Procesa render/input pendientes para que el modal se repinte durante el trabajo sincrónico.
    try {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [Action]{},
            [System.Windows.Threading.DispatcherPriority]::Background
        )
    } catch { }
}

function Show-ServiceProgressModal {
    param([string]$Title, [string]$Subtitle = '', [int]$Total = 0)
    try {
        $reader2 = New-Object System.Xml.XmlNodeReader $progressXaml
        $script:ProgressWindow = [Windows.Markup.XamlReader]::Load($reader2)
        $script:ProgressWindow.Owner = $window
        $script:ProgressWindow.FindName('PgbTitle').Text = $Title
        $script:ProgressWindow.FindName('PgbSubtitle').Text = $Subtitle
        $script:ProgressItems = $script:ProgressWindow.FindName('PgbItems')
        $script:ProgressScroll = $script:ProgressWindow.FindName('PgbScroll')
        $script:ProgressCancelled = $false
        $cancelBtn = $script:ProgressWindow.FindName('PgbCancel')
        if ($null -ne $cancelBtn) {
            $cancelBtn.Add_Click({
                $script:ProgressCancelled = $true
                $script:ProgressWindow.FindName('PgbCancel').Content = '⏹ CANCELANDO...'
                $script:ProgressWindow.FindName('PgbCancel').IsEnabled = $false
                Update-UI -Log 'Cancelación solicitada por el usuario; se detendrá al terminar el paso actual.' -LogColor '#FFAA00'
            })
        }

        # Un único timer de reloj, reutilizado en todas las operaciones.
        if ($null -eq $script:ProgressTimer) {
            $script:ProgressTimer = New-Object System.Windows.Threading.DispatcherTimer
            $script:ProgressTimer.Interval = [TimeSpan]::FromMilliseconds(250)
            $script:ProgressTimer.Add_Tick({
                if ($null -eq $script:ProgressWindow -or $null -eq $script:ProgressStopwatch) { return }
                $el = $script:ProgressStopwatch.Elapsed
                try {
                    $script:ProgressWindow.FindName('PgbElapsed').Text = "Tiempo: $($el.Minutes.ToString('00')):$($el.Seconds.ToString('00'))"
                } catch { }
            })
        }
        $script:ProgressStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:ProgressTimer.Start()

        Set-AllButtonsEnabled -Enabled $false
        $script:ProgressWindow.Show()
        Pump-UI
    } catch {
        Update-UI -Log "No se pudo mostrar el modal de progreso: $($_.Exception.Message)" -LogColor "#FFAA00"
    }
}

function Update-ServiceProgressModal {
    param([string]$Service, [string]$Status, [int]$Done = 0, [int]$Total = 0, [string]$Color = '#FFFFFF')
    if ($null -eq $script:ProgressWindow) { return }
    try {
        # El marco de la barra adopta el color semántico del paso (éxito/aviso/error).
        # Se reemplaza el recurso (no se muta) porque WPF puede congelar el brush al aplicar el template.
        if ($null -ne $script:ProgressWindow.Resources['PgbFrameBrush']) {
            $script:ProgressWindow.Resources['PgbFrameBrush'] = ([System.Windows.Media.BrushConverter]::new()).ConvertFromString($Color)
        }
        if ($Service) {
            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = "  • $Service : $Status"
            $tb.Foreground = ([System.Windows.Media.BrushConverter]::new()).ConvertFromString($Color)
            $tb.FontSize = 11
            $tb.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
            $script:ProgressItems.Children.Add($tb) | Out-Null
            $script:ProgressScroll.ScrollToEnd()
        }
        if ($Total -gt 0) {
            $pct = [int](100 * $Done / $Total)
            $script:ProgressWindow.FindName('PgbBar').Value = [double]$pct
            $script:ProgressWindow.FindName('PgbPercent').Text = "$pct%"
            $script:ProgressWindow.FindName('PgbCount').Text = "$Done / $Total"
            $eta = $script:ProgressWindow.FindName('PgbEta')
            if ($null -ne $eta -and $null -ne $script:ProgressStopwatch -and $Done -gt 0) {
                $sec = [int]($script:ProgressStopwatch.Elapsed.TotalSeconds * ($Total - $Done) / $Done)
                if ($sec -lt 0) { $sec = 0 }
                $eta.Text = "Restante: $(([int]($sec / 60)).ToString('00')):$(($sec % 60).ToString('00'))"
            }
        }
        Pump-UI
    } catch { }
}

function Close-ServiceProgressModal {
    try {
        if ($null -ne $script:ProgressTimer) { $script:ProgressTimer.Stop() }
        if ($null -ne $script:ProgressWindow) { $script:ProgressWindow.Close() }
    } catch { }
    finally {
        $script:ProgressWindow = $null
        $script:ProgressStopwatch = $null
        $script:ProgressCancelled = $false
        Set-AllButtonsEnabled -Enabled $true
        Pump-UI
    }
}

# Ajustar el tamano inicial al area util de la pantalla. La ventana puede
# maximizarse y redimensionarse; el contenido se desplaza si no cabe.
try {
    $workArea = [System.Windows.SystemParameters]::WorkArea
    $window.MaxWidth  = [Math]::Max(700, [double]$workArea.Width)
    $window.MaxHeight = [Math]::Max(560, [double]$workArea.Height)
    $desiredWidth  = [Math]::Min(1040, ([double]$workArea.Width - 40))
    $desiredHeight = [Math]::Min(880, ([double]$workArea.Height - 40))
    $window.Width  = [Math]::Max([double]$window.MinWidth,  $desiredWidth)
    $window.Height = [Math]::Max([double]$window.MinHeight, $desiredHeight)
} catch { }

# Mapeo de Elementos
$MainBorder    = $window.FindName("MainBorder")
$MainShadow    = $window.FindName("MainShadow")
$TitleBar      = $window.FindName("TitleBar")
$TxtTitle      = $window.FindName("TxtTitle")
$BtnTheme      = $window.FindName("BtnTheme")
$BtnMinimize   = $window.FindName("BtnMinimize")
$BtnClose      = $window.FindName("BtnClose")
$TxtStatusTitle= $window.FindName("TxtStatusTitle")
$TxtUpdateTitle= $window.FindName("TxtUpdateTitle")
$TxtVersionLabel=$window.FindName("TxtVersionLabel")
$TxtMainHeader = $window.FindName("TxtMainHeader")
$HeaderShadow  = $window.FindName("HeaderShadow")
$TxtSubHeader  = $window.FindName("TxtSubHeader")
$PanelStatus   = $window.FindName("PanelStatus")
$PanelUpdate   = $window.FindName("PanelUpdate")
$PanelLog      = $window.FindName("PanelLog")
$TxtVersion    = $window.FindName("TxtVersion")
$TxtEdition    = $window.FindName("TxtEdition")
$TxtLanguage   = $window.FindName("TxtLanguage")
$TxtArch       = $window.FindName("TxtArch")
$TxtUpdate     = $window.FindName("TxtUpdate")
$ProgressBar   = $window.FindName("ProgressBar")
$TxtProgress   = $window.FindName("TxtProgress")
$TxtDownloadStatus = $window.FindName("TxtDownloadStatus")
$TxtLog        = $window.FindName("TxtLog")
$ScrollLog     = $window.FindName("ScrollLog")
$BtnRefresh    = $window.FindName("BtnRefresh")
$BtnRepairWMI  = $window.FindName("BtnRepairWMI")
$BtnUpdate     = $window.FindName("BtnUpdate")
$BtnInventory  = $window.FindName("BtnInventory")
$BtnDownload   = $window.FindName("BtnDownload")
$BtnStopDownload = $window.FindName("BtnStopDownload")
$BtnPauseFile  = $window.FindName("BtnPauseFile")
$BtnResumeFile = $window.FindName("BtnResumeFile")
$BtnWizardBack   = $window.FindName("BtnWizardBack")
$BtnWizardNext   = $window.FindName("BtnWizardNext")
$BtnWizardFail   = $window.FindName("BtnWizardFail")
$BtnWizardReset  = $window.FindName("BtnWizardReset")
$TxtWizardStep   = $window.FindName("TxtWizardStep")
$TxtWizardHint   = $window.FindName("TxtWizardHint")
$TxtWizardHistory= $window.FindName("TxtWizardHistory")
$BtnService    = $window.FindName("BtnService")
$BtnStopAllServices = $window.FindName("BtnStopAllServices")
$BtnManageServices = $window.FindName("BtnManageServices")
$BtnReport     = $window.FindName("BtnReport")
$BtnProfiles   = $window.FindName("BtnProfiles")
$BtnSchedule   = $window.FindName("BtnSchedule")
$BtnSimulate   = $window.FindName("BtnSimulate")
$BtnLogVerbosity = $window.FindName("BtnLogVerbosity")
$TxtLogFilter  = $window.FindName("TxtLogFilter")
$BtnLog        = $window.FindName("BtnLog")
$CmbSQLVersion = $window.FindName("CmbSQLVersion")
$BtnMakeFolders= $window.FindName("BtnMakeFolders")
$BtnCatalog    = $window.FindName("BtnCatalog")
$BtnOpenRoot   = $window.FindName("BtnOpenRoot")
$BtnRestart    = $window.FindName("BtnRestart")

$script:DetectedInfo   = @{}
$script:InstallerPath  = ""
$script:Inventory      = @()
# Se sobrescribe con el LCID de la instancia (1033 => ENU) en Refresh-Detection.
$script:PreferredLang  = "ENU"
$script:InstallerProcess = $null
$script:TickHandler    = $null
$script:DownloadJob    = $null
$script:DownloadResults = @()
$script:DownloadTotal  = 0
$script:DownloadTickHandler = $null
$script:DownloadCurrentFile = ""
$script:DownloadCurrentBytes = 0
$script:DownloadCurrentTotal = 0
# Centro de descargas Pro: muestreo de velocidad, ETA y cola persistente.
$script:DownloadLastSampleTime = $null
$script:DownloadLastSampleBytes = 0
$script:DownloadSpeedBps = 0
$script:DownloadEtaSeconds = 0
$script:DownloadQueuePath = ''

# Wizard WPF de 4 pasos: estado compartido con modules/Wizard.ps1 (testeable).
$script:WizardState = $null
$TxtWizardHints = @{
    'Diagnosticar' = 'Pulsa REFRESCAR ESTADO para detectar instancia, versión, SP e idioma.'
    'Respaldar'    = 'Crea un punto de restauración antes de aplicar cualquier cambio.'
    'Aplicar'      = 'Instala el Service Pack recomendado desde ACTUALIZACIÓN Y DESCARGAS.'
    'Verificar'    = 'Comprueba los servicios y exporta el informe antes/después.'
}

function Update-SQLPrimeWizardUI {
    if (-not $script:WizardState) { $script:WizardState = New-SQLPrimeWizardState }
    $state = $script:WizardState
    $steps = @($state.Steps)
    $idx = [array]::IndexOf($steps, [string]$state.CurrentStep)
    if ($idx -lt 0) { $idx = 0 }
    $TxtWizardStep.Text = "Paso $($idx + 1)/$($steps.Count): $($state.CurrentStep)"
    if ($TxtWizardHint) { $TxtWizardHint.Text = $TxtWizardHints[[string]$state.CurrentStep] }
    if ($TxtWizardHistory) {
        $recent = @($state.History | Select-Object -Last 4)
        $lines = foreach ($h in $recent) { "$($h.Step)=$($h.Status)" }
        $TxtWizardHistory.Text = if ($lines.Count) { "Historial: $($lines -join ' · ')" } else { 'Historial: (vacío)' }
    }
    $BtnWizardBack.IsEnabled = ($idx -gt 0)
    $BtnWizardNext.IsEnabled = $true
    $BtnWizardFail.IsEnabled = $true
}

function Complete-SQLPrimeWizardStep {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('Diagnosticar','Respaldar','Aplicar','Verificar')][string]$Step,
        [ValidateSet('Pending','Running','Done','Failed','Skipped')][string]$Status = 'Done'
    )
    try {
        if (-not $script:WizardState) { $script:WizardState = New-SQLPrimeWizardState }
        $script:WizardState = Step-SQLPrimeWizard -State $script:WizardState -Step $Step -Status $Status
        Update-SQLPrimeWizardUI
        try {
            Write-SQLPrimeStructuredLog -Level INFO -Component 'wizard' -OperationId $script:DownloadOperationId `
                -Message "Wizard step: $Step ($Status)" `
                -Data @{ step=$Step; status=$Status; current=$script:WizardState.CurrentStep; history=@($script:WizardState.History).Count }
        } catch { }
    } catch {
        # Los saltos invalidos se ignoran: nunca deben romper la accion del usuario.
        Update-UI -Log "Wizard: transición no permitida ($Step -> $Status)." -LogColor '#FFAA00'
    }
}

function Reset-SQLPrimeWizardUI {
    $script:WizardState = New-SQLPrimeWizardState
    Update-SQLPrimeWizardUI
    Update-UI -Log 'Asistente reiniciado: Paso 1/4 Diagnosticar.' -LogColor '#00CCFF'
}

# Estado inicial del stepper (los controles ya fueron mapeados mas arriba).
try { Update-SQLPrimeWizardUI } catch { }
$script:ReportPath     = Join-Path $PSScriptRoot "Inventario_Instaladores_SQL2008.txt"
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:DownloadTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:DownloadTimer.Interval = [TimeSpan]::FromMilliseconds(500)

# ------------------------------------------------------------------------------
# Handler UNICO del timer de descargas. Se define fuera de Start-InstallerDownloads
# para que cada pulsacion de DETENER/DESCARGAR no deje handlers antiguos
# suscritos (causa del bucle "No se puede enlazar el argumento Job porque es null").
# ------------------------------------------------------------------------------
$script:DownloadTickHandler = $null
$script:DownloadTimerTick = {
    try {
        # Sin job activo: solo parar el timer. Nunca se desuscribe aqui y nunca
        # se llama a Receive-Job con un job nulo.
        if (-not $script:DownloadJob) {
            $script:DownloadTimer.Stop()
            $TxtDownloadStatus.Text = ""
            $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Collapsed
            $BtnDownload.IsEnabled = $true
            $BtnStopDownload.IsEnabled = $false
            $BtnPauseFile.IsEnabled = $false
            $BtnResumeFile.IsEnabled = $false
            return
        }
        $job = Get-Job -Id $script:DownloadJob.Id -ErrorAction SilentlyContinue
        if (-not $job) {
            $script:DownloadTimer.Stop()
            $script:DownloadJob = $null
            $TxtDownloadStatus.Text = ""
            $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Collapsed
            $BtnDownload.IsEnabled = $true
            $BtnStopDownload.IsEnabled = $false
            $BtnPauseFile.IsEnabled = $false
            $BtnResumeFile.IsEnabled = $false
            return
        }

        $newItems = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
        foreach ($r in $newItems) {
            if ($r.PSObject.Properties.Name -contains "Type" -and $r.Type -eq "PROGRESS") {
                $prevFile = $script:DownloadCurrentFile
                $script:DownloadCurrentFile  = $r.Name
                $script:DownloadCurrentBytes = [int64]$r.Bytes
                $script:DownloadCurrentTotal = [int64]$r.Total

                # Velocidad media movil y ETA basado en bytes/s (no en numero de pasos).
                $now = [DateTime]::UtcNow
                if ($prevFile -ne $script:DownloadCurrentFile -or $null -eq $script:DownloadLastSampleTime) {
                    $script:DownloadSpeedBps = 0
                    $script:DownloadLastSampleBytes = [int64]$r.Bytes
                } else {
                    $secs = ($now - $script:DownloadLastSampleTime).TotalSeconds
                    if ($secs -gt 0.05) {
                        $instant = ([int64]$r.Bytes - [int64]$script:DownloadLastSampleBytes) / $secs
                        if ($instant -gt 0) {
                            $script:DownloadSpeedBps = if ($script:DownloadSpeedBps -gt 0) {
                                (0.6 * $script:DownloadSpeedBps) + (0.4 * $instant)
                            } else { $instant }
                        }
                    }
                }
                $script:DownloadLastSampleTime = $now
                $script:DownloadLastSampleBytes = [int64]$r.Bytes
                $remaining = [Math]::Max(0, [int64]$r.Total - [int64]$r.Bytes)
                $script:DownloadEtaSeconds = if ($script:DownloadSpeedBps -gt 0) {
                    [int][math]::Round($remaining / $script:DownloadSpeedBps)
                } else { 0 }

                $fraction = 0
                if ($r.Total -gt 0) { $fraction = [double]$r.Bytes / [double]$r.Total }
                $done = $script:DownloadResults.Count
                $totalItems = [Math]::Max(1, $script:DownloadTotal)
                $overallPct = 0
                if ($totalItems -gt 0) {
                    $overallPct = [int](100 * (($done + $fraction) / $totalItems))
                    $ProgressBar.Value = [Math]::Min(100, $overallPct)
                } else {
                    $ProgressBar.Value = [Math]::Min(95, [int](5 + 90 * ($done / $totalItems)))
                }
                $filePct = if ($r.Total -gt 0) { [math]::Round(100 * $r.Bytes / $r.Total, 1) } else { 0 }
                $mbNow   = [math]::Round($r.Bytes / 1MB, 1)
                $mbTot   = if ($r.Total -gt 0) { [math]::Round($r.Total / 1MB, 1) } else { 0 }
                $mbps    = [math]::Round($script:DownloadSpeedBps / 1MB, 2)
                $etaTxt  = if ($script:DownloadEtaSeconds -gt 0) {
                    "ETA $(([int]($script:DownloadEtaSeconds / 60)).ToString('00')):$(($script:DownloadEtaSeconds % 60).ToString('00'))"
                } else { 'ETA calculando' }
                $fileIdx = $done + 1
                $status  = "Descargando $fileIdx/$($script:DownloadTotal): $($r.Name) - $filePct% ($mbNow / $mbTot MB) · $mbps MB/s · $etaTxt"
                $TxtDownloadStatus.Text = $status
                $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Visible
                $TxtProgress.Text = "$([int][math]::Floor($filePct))%"

                $BtnPauseFile.IsEnabled = $true
                $BtnResumeFile.IsEnabled = $false
                if ($script:DownloadQueuePath -and (Get-Command Set-SQLPrimeDownloadQueueState -ErrorAction SilentlyContinue)) {
                    try {
                        Set-SQLPrimeDownloadQueueState -Name $r.Name -State 'Downloading' -BaseDir $PSScriptRoot -Bytes ([int64]$r.Bytes) -Total ([int64]$r.Total) -SpeedBps $script:DownloadSpeedBps -EtaSeconds $script:DownloadEtaSeconds | Out-Null
                    } catch { }
                }
                continue
            }
            $script:DownloadResults += $r
            if ($r.Status -eq "OK") {
                $mode = if ($r.Resumed) { "REANUDADO" } else { "DESCARGADO" }
                $pctStr = ''
                if ($r.Total -gt 0) { $pctStr = " ($([math]::Round(100 * $r.Bytes / $r.Total, 1))%)" }
                $hashStr = ''
                try { if ($r.PSObject.Properties.Name -contains 'Sha256' -and $r.Sha256) { $hashStr = " | SHA256: $($r.Sha256)" } } catch { }
                Update-UI -Log "$mode`: $($r.Name) ($([math]::Round($r.Bytes / 1MB, 1)) MB$pctStr) -> $($r.Path)$hashStr" -LogColor "#00FF00"
                try { if (Get-Command Write-SQLPrimeStructuredLog -ErrorAction SilentlyContinue) { Write-SQLPrimeStructuredLog -Level INFO -Component 'download' -OperationId $script:DownloadOperationId -Message "Download completed: $($r.Name)" -Data @{ name=$r.Name; path=$r.Path; bytes=$r.Bytes; resumed=$r.Resumed; sha256=$r.Sha256; hashChecked=$r.HashChecked } } } catch { }
                if ($script:DownloadQueuePath -and (Get-Command Set-SQLPrimeDownloadQueueState -ErrorAction SilentlyContinue)) {
                    try { Set-SQLPrimeDownloadQueueState -Name $r.Name -State 'Completed' -BaseDir $PSScriptRoot | Out-Null } catch { }
                }
            } elseif ($r.Status -eq 'PAUSED') {
                Update-UI -Log "PAUSADO: $($r.Name). El fichero .part se conserva para reanudarlo." -LogColor '#FFAA00'
                if ($script:DownloadQueuePath -and (Get-Command Set-SQLPrimeDownloadQueueState -ErrorAction SilentlyContinue)) {
                    try { Set-SQLPrimeDownloadQueueState -Name $r.Name -State 'Paused' -BaseDir $PSScriptRoot -Bytes ([int64]$r.Bytes) -Total ([int64]$r.Total) | Out-Null } catch { }
                }
                $BtnPauseFile.IsEnabled = $false
                $BtnResumeFile.IsEnabled = $true
            } else {
                Update-UI -Log "FALLO: $($r.Name) - $($r.Message)" -LogColor "#FF0000"
                try { if (Get-Command Write-SQLPrimeStructuredLog -ErrorAction SilentlyContinue) { Write-SQLPrimeStructuredLog -Level ERROR -Component 'download' -OperationId $script:DownloadOperationId -Message "Download failed: $($r.Name)" -Data @{ name=$r.Name; message=$r.Message } } } catch { }
                if ($script:DownloadQueuePath -and (Get-Command Set-SQLPrimeDownloadQueueState -ErrorAction SilentlyContinue)) {
                    try { Set-SQLPrimeDownloadQueueState -Name $r.Name -State 'Error' -BaseDir $PSScriptRoot -LastError ([string]$r.Message) | Out-Null } catch { }
                }
            }
            if ($script:DownloadTotal -gt 0) {
                $ProgressBar.Value = [Math]::Min(95, 5 + [int](90 * $script:DownloadResults.Count / $script:DownloadTotal))
            }
        }

        if ($job.State -ne "Running") {
            $script:DownloadTimer.Stop()
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            $script:DownloadJob = $null
            $ProgressBar.Value = 100
            $TxtProgress.Text = "100%"
            $TxtDownloadStatus.Text = ""
            $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Collapsed
            $script:DownloadCurrentFile = ""
            $script:DownloadCurrentBytes = 0
            $script:DownloadCurrentTotal = 0
            $BtnDownload.IsEnabled = $true
            $BtnStopDownload.IsEnabled = $false
            $BtnPauseFile.IsEnabled = $false
            $BtnResumeFile.IsEnabled = $false
            $script:DownloadLastSampleTime = $null
            $script:DownloadLastSampleBytes = 0
            $ok = @($script:DownloadResults | Where-Object { $_.Status -eq "OK" }).Count
            Update-UI -Log "Descargas terminadas: $ok correctas de $($script:DownloadTotal)." -LogColor "#00FF00"
            Refresh-Detection
        }
    } catch {
        # Un solo aviso por sesion: nunca se repite el error del timer.
        $script:DownloadTimer.Stop()
        $script:DownloadJob = $null
        $TxtDownloadStatus.Text = ""
        $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Collapsed
        $script:DownloadCurrentFile = ""
        $BtnDownload.IsEnabled = $true
        $BtnStopDownload.IsEnabled = $false
        $BtnPauseFile.IsEnabled = $false
        $BtnResumeFile.IsEnabled = $false
        if (-not $script:DownloadWarningShown) {
            $script:DownloadWarningShown = $true
            Update-UI -Log "AVISO: existe un error de supervisión o una descarga incompleta. Se detuvo el monitor; pulsa DESCARGAR FALTANTES para continuar desde el último byte." -LogColor "#FFAA00"
        }
    }
}

function Register-DownloadTimerTick {
    if ($script:DownloadTickHandler) { return }
    $script:DownloadTickHandler = $script:DownloadTimerTick
    $script:DownloadTimer.Add_Tick($script:DownloadTickHandler)
}

# ==============================================================================
# 5. MOTOR DE TEMAS
# ==============================================================================
# Paleta de la barra de progreso: WPF congela los GradientStop cuando aplica el
# template, así que se reemplaza el brush completo enlazado con DynamicResource.
function New-SQLPrimeProgressBrush {
    param([string[]]$Palette)

    $brush = [System.Windows.Media.LinearGradientBrush]::new()
    $brush.StartPoint = [System.Windows.Point]::new(0, 0)
    $brush.EndPoint = [System.Windows.Point]::new(1, 0)
    $converter = [System.Windows.Media.ColorConverter]::new()
    $offsets = @(0, 0.5, 1)
    for ($i = 0; $i -lt $Palette.Count; $i++) {
        $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new(
            $converter.ConvertFromString($Palette[$i]), [double]$offsets[$i]
        ))
    }
    return $brush
}

function Set-SQLPrimeProgressPalette {
    param([bool]$Dark = $true)

    if ($null -eq $window -or $null -eq $window.Resources['ProgressFillBrush']) { return }
    $palette = if ($Dark) { @('#00F5FF', '#7C4DFF', '#FF3DFF') } else { @('#0284C7', '#6366F1', '#D946EF') }
    try {
        if (Get-Command Get-SQLPrimeDesignTokens -ErrorAction SilentlyContinue) {
            $tokens = Get-SQLPrimeDesignTokens -Theme $(if ($Dark) { 'Dark' } else { 'Light' }) -BaseDir $PSScriptRoot
            if ($null -ne $tokens -and $tokens.progress.Count -eq 3) { $palette = @($tokens.progress) }
        }
        $window.Resources['ProgressFillBrush'] = New-SQLPrimeProgressBrush -Palette $palette
    } catch { }
}

function Apply-Theme {
    param([string]$ThemeName)
    
    $isDark = $true
    if ($ThemeName -eq "Light") { $isDark = $false }
    elseif ($ThemeName -eq "Auto") {
        $regTheme = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
        if ($regTheme.AppsUseLightTheme -eq 1) { $isDark = $false }
    }

    $cc = [System.Windows.Media.ColorConverter]::new()
    $bc = [System.Windows.Media.BrushConverter]::new()

    # Hover de botones y del listado: se actualizan los brushes dinámicos del XAML
    # para que el efecto respete el tema oscuro/claro sin recargar la interfaz.
    $hoverColors = if ($isDark) {
        @{ HoverBg='#2A2A3D'; HoverFg='#00FFFF'; PressedBg='#3A3A52';
           CloseHoverBg='#C42B1C'; CloseHoverFg='#FFFFFF';
           ItemHoverBg='#233A4A'; ItemHoverFg='#00FFFF';
           ItemSelectedBg='#173A4A'; ItemSelectedFg='#00FFFF' }
    } else {
        @{ HoverBg='#D6E4F0'; HoverFg='#005A9E'; PressedBg='#BFD4E6';
           CloseHoverBg='#C42B1C'; CloseHoverFg='#FFFFFF';
           ItemHoverBg='#DCEBF7'; ItemHoverFg='#005A9E';
           ItemSelectedBg='#C9E2F5'; ItemSelectedFg='#004578' }
    }
    foreach ($key in $hoverColors.Keys) {
        try {
            $brush = $window.Resources[$key]
            if ($null -ne $brush) { $brush.Color = $cc.ConvertFromString($hoverColors[$key]) }
        } catch { }
    }

    Set-SQLPrimeProgressPalette -Dark $isDark

    if ($isDark) {
        $bgBrush = $bc.ConvertFromString("#0D0D14")
        $borderBrush = $bc.ConvertFromString("#00FFFF")
        $panelBg = $bc.ConvertFromString("#1A1A2A")
        $panelBorder = $bc.ConvertFromString("#333355")
        $textColor = $bc.ConvertFromString("#FFFFFF")
        $subTextColor = $bc.ConvertFromString("#8888AA")
        $logBg = $bc.ConvertFromString("#08080C")
        $comboBg = $bc.ConvertFromString("#222233")
        $comboFg = $bc.ConvertFromString("#FFFFFF")
        $progressBg = $bc.ConvertFromString("#11111A")
        $progressFg = $bc.ConvertFromString("#00FFFF")
        # Texto blanco con sombra (definida en XAML) para que se lea sobre el degradado.
        $txtProgressFg = $bc.ConvertFromString("#FFFFFF")

        $MainBorder.Background = $bgBrush
        $MainBorder.BorderBrush = $borderBrush
        $MainShadow.Color = $cc.ConvertFromString("#00FFFF")
        $TitleBar.Background = $bc.ConvertFromString("#11111A")
        $TxtTitle.Foreground = $borderBrush
        $BtnTheme.Foreground = $textColor
        $BtnMinimize.Foreground = $textColor
        $BtnClose.Foreground = $textColor
        $TxtMainHeader.Foreground = $bc.ConvertFromString("#FF00FF")
        $HeaderShadow.Color = $cc.ConvertFromString("#FF00FF")
        $TxtSubHeader.Foreground = $subTextColor
        $TxtStatusTitle.Foreground = $bc.ConvertFromString("#00CCFF")
        $TxtUpdateTitle.Foreground = $bc.ConvertFromString("#FFAA00")
        $TxtVersionLabel.Foreground = $borderBrush
        if ($TxtDownloadStatus) { $TxtDownloadStatus.Foreground = $bc.ConvertFromString("#00CCFF") }
        
        $PanelStatus.Background = $panelBg
        $PanelUpdate.Background = $panelBg
        $PanelLog.Background = $logBg
        $PanelStatus.BorderBrush = $panelBorder
        $PanelUpdate.BorderBrush = $panelBorder
        $PanelLog.BorderBrush = $bc.ConvertFromString("#00AAAA")
        
        $TxtVersion.Foreground = $textColor
        $TxtEdition.Foreground = $textColor
        $TxtLanguage.Foreground = $textColor
        $TxtArch.Foreground = $textColor
        $TxtUpdate.Foreground = $bc.ConvertFromString("#FFD700")
        $TxtLog.Foreground = $bc.ConvertFromString("#00FFCC")
        
        $ProgressBar.Background = $progressBg
        $ProgressBar.Foreground = $progressFg
        $TxtProgress.Foreground = $txtProgressFg
        
        # El selector de versión se crea después de Apply-Theme: se estila aquí
        # cuando ya tiene elementos (y también al cambiar de tema).
        if ($CmbSQLVersion) {
            $CmbSQLVersion.Background = $comboBg
            $CmbSQLVersion.Foreground = $comboFg
            $CmbSQLVersion.BorderBrush = $borderBrush
            foreach ($item in $CmbSQLVersion.Items) {
                $item.Background = $comboBg
                $item.Foreground = $comboFg
            }
        }
    } else {
        $bgBrush = $bc.ConvertFromString("#F4F6F9")
        $borderBrush = $bc.ConvertFromString("#005A9E")
        $panelBg = $bc.ConvertFromString("#FFFFFF")
        $panelBorder = $bc.ConvertFromString("#CCCCCC")
        $textColor = $bc.ConvertFromString("#333333")
        $subTextColor = $bc.ConvertFromString("#555555")
        $logBg = $bc.ConvertFromString("#FFFFFF")
        $comboBg = $bc.ConvertFromString("#FFFFFF")
        $comboFg = $bc.ConvertFromString("#333333")
        $progressBg = $bc.ConvertFromString("#E1E5EA")
        $progressFg = $bc.ConvertFromString("#005A9E")
        $txtProgressFg = $bc.ConvertFromString("#FFFFFF")

        $MainBorder.Background = $bgBrush
        $MainBorder.BorderBrush = $borderBrush
        $MainShadow.Color = $cc.ConvertFromString("#005A9E")
        $TitleBar.Background = $bc.ConvertFromString("#E1E5EA")
        $TxtTitle.Foreground = $borderBrush
        $BtnTheme.Foreground = $textColor
        $BtnMinimize.Foreground = $textColor
        $BtnClose.Foreground = $textColor
        $TxtMainHeader.Foreground = $bc.ConvertFromString("#D80073")
        $HeaderShadow.Color = $cc.ConvertFromString("#D80073")
        $TxtSubHeader.Foreground = $subTextColor
        $TxtStatusTitle.Foreground = $bc.ConvertFromString("#00695C")
        $TxtUpdateTitle.Foreground = $bc.ConvertFromString("#A04000")
        $TxtVersionLabel.Foreground = $borderBrush
        if ($TxtDownloadStatus) { $TxtDownloadStatus.Foreground = $bc.ConvertFromString("#005A9E") }

        $PanelStatus.Background = $panelBg
        $PanelUpdate.Background = $panelBg
        $PanelLog.Background = $logBg
        $PanelStatus.BorderBrush = $panelBorder
        $PanelUpdate.BorderBrush = $panelBorder
        $PanelLog.BorderBrush = $borderBrush

        $TxtVersion.Foreground = $textColor
        $TxtEdition.Foreground = $textColor
        $TxtLanguage.Foreground = $textColor
        $TxtArch.Foreground = $textColor
        $TxtUpdate.Foreground = $bc.ConvertFromString("#A04000")
        $TxtLog.Foreground = $bc.ConvertFromString("#00695C")
        
        $ProgressBar.Background = $progressBg
        $ProgressBar.Foreground = $progressFg
        $TxtProgress.Foreground = $txtProgressFg
        
        # El selector de versión se crea después de Apply-Theme: se estila aquí
        # cuando ya tiene elementos (y también al cambiar de tema).
        if ($CmbSQLVersion) {
            $CmbSQLVersion.Background = $comboBg
            $CmbSQLVersion.Foreground = $comboFg
            $CmbSQLVersion.BorderBrush = $borderBrush
            foreach ($item in $CmbSQLVersion.Items) {
                $item.Background = $comboBg
                $item.Foreground = $comboFg
            }
        }
    }
}

# Botón de tema: un clic rota Oscuro -> Claro -> Auto y muestra el modo activo.
$script:ThemeLabels = @{
    Dark  = "🌙 OSCURO"
    Light = "☀️ CLARO"
    Auto  = "💻 AUTO"
}
function Update-ThemeButton {
    $key = $script:CurrentTheme
    if (-not $script:ThemeLabels.ContainsKey($key)) {
        $key = "Auto"
        $script:CurrentTheme = $key
    }
    $label = $script:ThemeLabels[$key]
    $BtnTheme.Content = "🎨 $label"
    $BtnTheme.ToolTip = "Tema actual: $label`nClic para cambiar: Oscuro → Claro → Auto"
}
Update-ThemeButton
Apply-Theme -ThemeName $script:CurrentTheme

# Inicializar selector multiversión (primera opción = todas las versiones).
$allItem = New-Object System.Windows.Controls.ComboBoxItem
$allItem.Content = "🌐 TODAS LAS VERSIONES (6.5 -> 2025)"
$allItem.Tag = "ALL"
$CmbSQLVersion.Items.Add($allItem) | Out-Null
foreach ($v in $script:SQLVersionCatalog) {
    $it = New-Object System.Windows.Controls.ComboBoxItem
    $it.Content = "$($v.Name)  [$($v.Key)]  -  $($v.Status)"
    $it.Tag = $v.Key
    $CmbSQLVersion.Items.Add($it) | Out-Null
}
$CmbSQLVersion.SelectedIndex = 0
# Volver a aplicar el tema para que el selector de versión quede uniforme.
Apply-Theme -ThemeName $script:CurrentTheme

# ==============================================================================
# 6. FUNCIONES LÓGICAS
# ==============================================================================
function Update-UI {
    param([string]$Log, [string]$LogColor = "#00FFCC")
    if (-not $Log) { return }

    # Un mensaje identico repetido (por ejemplo un error de timer) solo se
    # escribe una vez por sesion. Asi nunca se inunda el log ni la pantalla.
    $key = $Log.Trim()
    if ($key -eq $script:LastLogEntry -and ((Get-Date) - $script:LastLogTime).TotalSeconds -lt 120) {
        return
    }
    $script:LastLogEntry = $key
    $script:LastLogTime = Get-Date

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$stamp] $Log`r`n"
    try {
        [System.IO.File]::AppendAllText($script:LogPath, $line, $script:LogUtf8)
    } catch { }

    # Historial en memoria para el filtro y los informes (Bloque C/E).
    if (-not $script:LogDisplayLines) { $script:LogDisplayLines = @() }
    $script:LogDisplayLines += [pscustomobject]@{ Time = $stamp.Substring(11); Text = $Log; Color = $LogColor }
    while ($script:LogDisplayLines.Count -gt 300) { $script:LogDisplayLines = @($script:LogDisplayLines | Select-Object -Skip 1) }

    if ($TxtLogFilter -and $TxtLogFilter.Text.Trim()) { return }

    $para = New-Object System.Windows.Documents.Paragraph
    $run = New-Object System.Windows.Documents.Run("$($stamp.Substring(11)) $Log")
    $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($LogColor)
    $para.Inlines.Add($run)
    $TxtLog.Document.Blocks.Add($para)
    while ($TxtLog.Document.Blocks.Count -gt 300) {
        $TxtLog.Document.Blocks.Remove($TxtLog.Document.Blocks.FirstBlock)
    }
    $ScrollLog.ScrollToEnd()
}

# ------------------------------------------------------------------------------
# Bloque H: logging estructurado (niveles, comandos, tiempos y comparativas).
# Toda linea pasa por Update-UI, por lo que tambien se escribe en SQL_PRIME.log.
# ------------------------------------------------------------------------------
$script:OperationStopwatch = $null

function Write-SQLPrimeLog {
    param(
        [ValidateSet('INFO','OK','WARN','ERROR','DEBUG','CMD','STEP','TIME')][string]$Level = 'INFO',
        [Parameter(Mandatory=$true)][string]$Message,
        [string]$Color
    )

    $verbosity = if ($script:Options -and $script:Options.LogVerbosity) { [string]$script:Options.LogVerbosity } else { 'Normal' }
    if ($Level -eq 'DEBUG' -and $verbosity -ne 'Diagnóstico') { return }
    if ($Level -eq 'CMD' -and $verbosity -eq 'Normal') { return }

    $meta = ''
    if ($script:OperationStopwatch) {
        $meta = '+' + ([math]::Round($script:OperationStopwatch.Elapsed.TotalSeconds, 2)).ToString('0.00') + 's'
    }
    $tag = switch ($Level) {
        'OK'    { '✔' }
        'WARN'  { '⚠' }
        'ERROR' { '✖' }
        'DEBUG' { '··' }
        'CMD'   { '>' }
        'STEP'  { '▸' }
        'TIME'  { '⏱' }
        default { '·' }
    }
    $palette = @{
        INFO='#00CCFF'; OK='#00FF00'; WARN='#FFAA00'; ERROR='#FF5555'
        DEBUG='#8888AA'; CMD='#FFD700'; STEP='#FF00FF'; TIME='#00FFFF'
    }
    $c = if ($Color) { $Color } else { $palette[$Level] }
    $sep = if ($meta) { ' ' } else { '' }
    Update-UI -Log "$tag$sep$meta $Message" -LogColor $c
}

function Write-SQLPrimeStateDiff {
    param([string]$Instance)
    if (-not $script:Snapshots -or $script:Snapshots.Count -eq 0) { return }
    $before = @($script:Snapshots | Where-Object { $_.Phase -eq 'ANTES' -and $_.Instance -eq $Instance })
    $after  = @($script:Snapshots | Where-Object { $_.Phase -eq 'DESPUES' -and $_.Instance -eq $Instance })
    if ($before.Count -eq 0 -or $after.Count -eq 0) { return }
    $changes = @()
    foreach ($b in $before) {
        $a = $after | Where-Object { $_.Service -eq $b.Service } | Select-Object -First 1
        if ($a -and ($a.Status -ne $b.Status -or $a.StartType -ne $b.StartType)) {
            $changes += "$($b.Service): $($b.Status)/$($b.StartType) -> $($a.Status)/$($a.StartType)"
        }
    }
    if ($changes.Count) {
        Write-SQLPrimeLog -Level INFO -Message "CAMBIOS DE ESTADO ($($changes.Count)):"
        foreach ($c in $changes) { Write-SQLPrimeLog -Level OK -Message "   $c" }
    } else {
        Write-SQLPrimeLog -Level INFO -Message 'CAMBIOS DE ESTADO: ninguno (los servicios ya estaban en el estado solicitado).'
    }
}

function Wait-SQLPrimeCondition {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$Condition,
        [int]$TimeoutSec = 5,
        [int]$PollMs = 200
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) { return $true }
        if ($script:ProgressCancelled) { return $false }
        Start-Sleep -Milliseconds $PollMs
        Pump-UI
    }
    return $false
}

function Get-SQLPrimePollMs {
    if ($script:Options -and $script:Options.PollIntervalMs) { return [int]$script:Options.PollIntervalMs }
    return 200
}

function Get-SQLServerInfo {
    $info = @{ MajorVersion=""; SPLevel=""; Edition=""; Language=""; LanguageCode=""; LanguageName="";
               Arch=""; Instance=""; InstanceId=""; ProductName=""; Build="";
               ProductVersion=""; IsQFE=$false }
    $info.Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $instanceKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    
    if (-not (Test-Path $instanceKey)) { return $info }
    $instances = Get-ItemProperty -Path $instanceKey
    $firstProp = $instances.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | Select-Object -First 1
    if (-not $firstProp) { return $info }
    
    $instanceId = $firstProp.Value
    $info.Instance = $firstProp.Name
    $info.InstanceId = $instanceId

    $verKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\CurrentVersion"
    if (Test-Path $verKey) {
        $verProps = Get-ItemProperty -Path $verKey
        $version = $verProps.CurrentVersion
        $info.Language = "$($verProps.Language)"
        # El LCID manda: 1033 -> ENU aunque el Windows y los ficheros locales estén en español.
        $info.LanguageCode = Get-LanguageCode -Lcid $info.Language
        $info.LanguageName = Get-LanguageDisplayName -Lcid $info.Language -Code $info.LanguageCode
        if ($version) {
            $buildInfo = if (Get-Command Resolve-SQLBuildInfo -ErrorAction SilentlyContinue) {
                Resolve-SQLBuildInfo -Build $version -BuildMap @($script:SQLBuildMap)
            } else { $null }
            if ($buildInfo) {
                $info.MajorVersion = $buildInfo.MajorVersion
                $info.Build = $buildInfo.Build
                $info.ProductName = $buildInfo.ProductName
                $info.SPLevel = $buildInfo.SPLevel
            } else {
                $parts = $version.Split('.')
                $info.MajorVersion = "$($parts[0]).$($parts[1])"
                $info.Build = $version
            }
        }
    }
    $setupKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\Setup"
    if (Test-Path $setupKey) {
        $setupProps = Get-ItemProperty -Path $setupKey
        $info.Edition = $setupProps.Edition
        $info.ProductVersion = "$($setupProps.Version)"
        if (Get-Command Test-SQLPrimeQfeBranch -ErrorAction SilentlyContinue) {
            $info.IsQFE = [bool](Test-SQLPrimeQfeBranch -MajorVersion $info.MajorVersion -ProductVersion $info.ProductVersion)
        } elseif ($info.MajorVersion -and $info.ProductVersion -match '^(\d+)\.(\d+)\.') {
            $msiMajor = "$($matches[1]).$($matches[2])"
            $info.IsQFE = ($msiMajor -ne $info.MajorVersion)
        }
    }
    return $info
}

# Acepta la carpeta heredada "SQLServer2008SPn" para instaladores R2: es un
# nombre antiguo válido, no una ubicación incorrecta.
# Funciones de inventario movidas a modules/Inventory.ps1 (Fase 0).

function Show-InstallerReport {
    $script:Inventory = Get-InstallerInventory
    $inv = $script:Inventory
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("SQL PRIME - INVENTARIO DE INSTALADORES SQL SERVER 2008 / 2008 R2")
    $lines.Add("Diagnostica. Repara. Actualiza.")
    $lines.Add("Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add("Carpeta base: $PSScriptRoot")
    if ($script:DetectedInfo.ProductName) {
        $lines.Add("Instancia detectada: $($script:DetectedInfo.ProductName) $($script:DetectedInfo.SPLevel) (build $($script:DetectedInfo.Build))")
        $lines.Add("Idioma detectado (LCID): $($script:DetectedInfo.Language) - $($script:DetectedInfo.LanguageName)")
        $lines.Add("Paquetes requeridos: $($script:PreferredLang)")
        $lines.Add("Arquitectura del sistema: $($script:DetectedInfo.Arch)")
        if ($script:DetectedInfo.ProductVersion) {
            $rama = if ($script:DetectedInfo.IsQFE) { "QFE/CU (10.52.x)" } else { "GDR (10.50.x)" }
            $lines.Add("Rama del producto: $rama (ProductVersion $($script:DetectedInfo.ProductVersion))")
        }
    }
    $lines.Add("")

    $lines.Add("=== FICHEROS ENCONTRADOS ($($inv.Count)) ===")
    if ($inv.Count -eq 0) { $lines.Add("  (ninguno)") }
    foreach ($f in $inv) {
        $lines.Add("  $($f.Folder)\$($f.Name)")
        $lines.Add("     Producto: $($f.Major) | SP: $($f.SP) | KB: $($f.KB) | Arq: $($f.Arch) | Idioma: $($f.Lang) | Tamaño: $($f.SizeMB) MB")
        if ($f.LegacyLayout) {
            $lines.Add("     Nota: carpeta heredada '$($f.Folder)' aceptada como válida para R2.")
        } elseif (-not $f.LocationOK) {
            $lines.Add("     AVISO: la carpeta '$($f.Folder)' no coincide; mover a '$($f.ExpectedFolder)'")
        }
        if ($f.Lang -ne $script:PreferredLang -and $script:PreferredLang) {
            $lines.Add("     AVISO: idioma $($f.Lang) no coincide con la instalación ($($script:PreferredLang)); este fichero NO se aplicará.")
        }
    }
    $lines.Add("")

    $lines.Add("=== FICHEROS ESPERADOS Y RUTA DE DESCARGA OFICIAL (IDIOMA $($script:PreferredLang)) ===")
    $missing = 0
    foreach ($def in ($script:SPDefinitions | Sort-Object Major, SPNumber)) {
        foreach ($arch in @("x64", "x86")) {
            $expected = Get-ExpectedFileName -MajorVersion $def.Major -SPNumber $def.SPNumber -Arch $arch -Lang $script:PreferredLang
            $found = @($inv | Where-Object { $_.Name -ieq $expected })
            if ($found.Count -gt 0) {
                $lines.Add("  [OK] $expected")
                $lines.Add("        $($found[0].FullName)")
            } else {
                $missing++
                $direct = Get-DirectUrl -Definition $def -Arch $arch -Lang $script:PreferredLang
                $lines.Add("  [FALTA] $expected")
                if ($direct) {
                    $lines.Add("        Directo $($script:PreferredLang): $direct")
                }
                $lines.Add("        Página oficial: $(Get-DownloadPage -Definition $def -Lang $script:PreferredLang)")
                $lines.Add("        Catálogo: $($def.Catalog)")
                $lines.Add("        Información KB$($def.KB): $($def.Support)")
            }
        }
    }
    $lines.Add("")
    $lines.Add("DESCARGA AUTOMÁTICA:")
    $lines.Add(" - Pulsa el botón 'DESCARGAR FALTANTES' para bajar los instaladores $($script:PreferredLang) que falten.")
    $lines.Add(" - Se guardan en la carpeta existente de su SP (incluidas las heredadas) o en una carpeta nueva 'SQLServer...SPn'.")
    $lines.Add(" - No se vuelven a descargar los ficheros que ya están presentes.")
    $lines.Add("")
    $lines.Add("DIAGNÓSTICO DEL FALLO DEL SERVICE PACK Y DEL SERVICIO:")
    $lines.Add(" - SP3 intentado (KB2979597 ESN, ALLINSTANCES, x64): exit -2068643838, 'No se actualizó ninguna característica...")
    $lines.Add("   ... durante la ejecución del programa de instalación'. Causa: paquete ESN sobre instalación LCID 1033/ENU,")
    $lines.Add("   además de estar la instancia en rama QFE/CU (Setup 10.52.4000.0 frente a motor 10.50.4000.0).")
    $lines.Add(" - Servicio MSSQLSERVER: evento 5597 (FILESTREAM no inicializado) -> 912 (fallo sqlagent100_msdb_upgrade.sql)")
    $lines.Add("   -> 3417 (no se puede recuperar master). SQL Agent: evento 103, no puede conectar con '(local)'.")
    $lines.Add(" - Solución: usar el paquete ENU, pulsar 'REPARAR SERVICIO SQL' y después reiniciar.")
    $lines.Add("")
    $lines.Add("NOTAS:")
    $lines.Add(" - Los Service Packs son acumulativos: SP4 (SQL Server 2008) y SP3 (SQL Server 2008 R2) incluyen todos los anteriores.")
    $lines.Add(" - El instalador debe coincidir con la arquitectura y, sobre todo, con el idioma de la instancia instalada.")
    $lines.Add(" - Referencias: https://support.microsoft.com/help/2979596 (SP4) y https://support.microsoft.com/help/2979597 (R2 SP3)")

    try {
        $lines -join "`r`n" | Set-Content -Path $script:ReportPath -Encoding UTF8 -Force
        Update-UI -Log "Informe guardado en: $($script:ReportPath) (faltan $missing ficheros para $($script:PreferredLang))" -LogColor "#00FF00"
        Start-Process notepad.exe -ArgumentList "`"$($script:ReportPath)`"" -ErrorAction SilentlyContinue
    } catch {
        Update-UI -Log "No se pudo guardar el informe: $($_.Exception.Message)" -LogColor "#FF0000"
    }
}

function Clear-PendingReboot {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $cleaned = $false
    foreach ($key in @("PendingFileRenameOperations", "PendingFileRenameOperations2")) {
        if (Get-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue
            $cleaned = $true
        }
    }
    if ($cleaned) { Update-UI -Log "Claves de reinicio pendiente eliminadas del registro." -LogColor "#FFFF00" }
    return $cleaned
}

# Estado mutuamente excluyente de los botones de servicios:
#  - Todos los servicios instalados Running  => Reparar desactivado, Desactivar activado.
#  - Todos los servicios instalados Stopped  => Desactivar desactivado, Reparar activado.
#  - Estado mixto                            => ambos activados.
#  - Sin instancia / sin servicios           => ambos desactivados.
function Update-ServiceActionButtons {
    param([string]$Instance)

    if ($null -eq $BtnService -or $null -eq $BtnStopAllServices) { return }
    # Mientras el modal de progreso esté abierto, Set-AllButtonsEnabled manda.
    if ($script:ProgressWindow) { return }

    if (-not $Instance) { $Instance = $script:DetectedInfo.Instance }
    if (-not $Instance) {
        $BtnService.IsEnabled = $false
        $BtnStopAllServices.IsEnabled = $false
        return
    }

    $installed = @()
    foreach ($name in @(Get-SQLServiceCandidates -Instance $Instance)) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc) { $installed += $svc }
    }
    if ($installed.Count -eq 0) {
        $BtnService.IsEnabled = $false
        $BtnStopAllServices.IsEnabled = $false
        return
    }

    $running = @($installed | Where-Object { $_.Status -eq 'Running' }).Count
    $stopped = @($installed | Where-Object { $_.Status -eq 'Stopped' }).Count

    if ($running -eq $installed.Count) {
        $BtnService.IsEnabled = $false
        $BtnStopAllServices.IsEnabled = $true
    } elseif ($stopped -eq $installed.Count) {
        $BtnService.IsEnabled = $true
        $BtnStopAllServices.IsEnabled = $false
    } else {
        $BtnService.IsEnabled = $true
        $BtnStopAllServices.IsEnabled = $true
    }
}

function Refresh-Detection {
    Update-UI -Log "Escaneando carpetas de instaladores y registro de SQL Server..." -LogColor "#00CCFF"

    $script:Inventory = Get-InstallerInventory
    $info = Get-SQLServerInfo

    # El LCID de la instancia manda sobre los ficheros que haya en las carpetas.
    $inventoryLangs = @($script:Inventory | ForEach-Object { $_.Lang } | Sort-Object -Unique)
    if ($info.LanguageCode) {
        $script:PreferredLang = $info.LanguageCode
    } elseif ($inventoryLangs.Count -gt 0) {
        $script:PreferredLang = $inventoryLangs[0]
    }
    $BtnDownload.IsEnabled = $true
    Show-InventorySummary

    if (-not $info.ProductName) {
        Update-UI -Log "No se pudo detectar una instancia válida de SQL Server (se admiten todas las versiones del catálogo)." -LogColor "#FF0000"
        $TxtVersion.Text = "Versión: No detectada"
        $TxtLanguage.Text = "Idioma: $($info.Language)"
        $TxtUpdate.Text  = "Sin instancia detectada.`nPulsa DESCARGAR FALTANTES o INVENTARIO / DESCARGAS para ver los ficheros y las rutas oficiales."
        $script:InstallerPath = ""
        $BtnUpdate.IsEnabled = $false
        Update-ServiceActionButtons -Instance ''
        return
    }

    $script:DetectedInfo = $info
    Update-ServiceActionButtons -Instance $info.Instance
    # Seleccionar automaticamente la version detectada en el combo multiversion.
    for ($i = 0; $i -lt $CmbSQLVersion.Items.Count; $i++) {
        if ("$($CmbSQLVersion.Items[$i].Tag)" -eq $info.MajorVersion) {
            $CmbSQLVersion.SelectedIndex = $i
            break
        }
    }
    $TxtVersion.Text  = "Versión: $($info.ProductName) - $($info.SPLevel)"
    $TxtEdition.Text  = "Edición: $($info.Edition)"
    $TxtLanguage.Text = "Idioma: $($info.Language) - $($info.LanguageName)"
    $TxtArch.Text     = "Arquitectura: $($info.Arch) ($($info.Build))"
    Update-UI -Log "Detectado: $($info.ProductName) $($info.SPLevel) (Build $($info.Build))" -LogColor "#00CCFF"
    Update-UI -Log "Idioma de la instalación: LCID $($info.Language) => paquetes $($script:PreferredLang)." -LogColor "#00FF00"

    if ($script:PreferredLang -eq "ENU" -and $inventoryLangs -contains "ESN" -and $inventoryLangs -notcontains "ENU") {
        Update-UI -Log "CONFLICTO: los instaladores locales son ESN, pero la instancia es ENU (1033). Los paquetes ESN NO se aplicarán." -LogColor "#FF0000"
    }

    if ($info.IsQFE) {
        Update-UI -Log "AVISO: rama QFE/CU (ProductVersion $($info.ProductVersion) frente a motor $($info.MajorVersion)). Un SP completo puede rechazarse con 'No se actualizó ninguna característica' / exit -2068643838." -LogColor "#FF0000"
    }

    # Los SP son acumulativos: se ofrece el más alto primero, con respaldo de los inferiores.
    $currentSP = 0
    if ($info.SPLevel -match 'SP(\d+)') { $currentSP = [int]$matches[1] }
    $needed = @($script:SPDefinitions | Where-Object {
        $_.Major -eq $info.MajorVersion -and $_.SPNumber -gt $currentSP
    } | Sort-Object SPNumber -Descending)

    if ($needed.Count -eq 0) {
        $TxtUpdate.Text = "✅ Ya tienes el Service Pack más alto disponible para tu versión ($($script:PreferredLang))."
        $BtnUpdate.IsEnabled = $false
        $BtnUpdate.Content = "✅ ACTUALIZADO"
        $script:InstallerPath = ""
        return
    }

    $otherArch = if ($info.Arch -eq "x64") { "x86" } else { "x64" }
    $chosenDef = $null
    $chosenInstaller = $null

    foreach ($def in $needed) {
        $candidate = Find-Installer -MajorVersion $def.Major -SPNumber $def.SPNumber -Arch $info.Arch -Lang $script:PreferredLang -Inventory $script:Inventory
        if (-not $candidate) {
            $candidate = Find-Installer -MajorVersion $def.Major -SPNumber $def.SPNumber -Arch $otherArch -Lang $script:PreferredLang -Inventory $script:Inventory
            if ($candidate) {
                Update-UI -Log "AVISO: el instalador es $($candidate.Arch) pero la arquitectura detectada es $($info.Arch)." -LogColor "#FFAA00"
            }
        }
        if ($candidate) { $chosenDef = $def; $chosenInstaller = $candidate; break }
    }

    if ($chosenInstaller) {
        $script:InstallerPath = $chosenInstaller.FullName
        $TxtUpdate.Text = "Recomendado: $($chosenDef.SP) (acumulativo, $($script:PreferredLang)).`nInstalador: $($chosenInstaller.Name)"
        $BtnUpdate.IsEnabled = $true
        $BtnUpdate.Content = "🚀 ACTUALIZAR A $($chosenDef.SP)"
        Update-UI -Log "Instalador seleccionado: $($chosenInstaller.Name) [$($chosenInstaller.Folder)]" -LogColor "#00FF00"
        if ($chosenDef.SPNumber -lt $needed[0].SPNumber) {
            Update-UI -Log "Nota: existe un SP superior ($($needed[0].SP)); se usa $($chosenDef.SP) por ser el descargado." -LogColor "#FFFF00"
        }
    } else {
        $top = $needed[0]
        $expected = Get-ExpectedFileName -MajorVersion $info.MajorVersion -SPNumber $top.SPNumber -Arch $info.Arch -Lang $script:PreferredLang
        $direct = Get-DirectUrl -Definition $top -Arch $info.Arch -Lang $script:PreferredLang
        $script:InstallerPath = ""
        $BtnUpdate.IsEnabled = $false
        $TxtUpdate.Text = "Falta: $expected`nDescarga: $(if ($direct) { $direct } else { Get-DownloadPage -Definition $top -Lang $script:PreferredLang })"
        Update-UI -Log "FALTA el instalador: $expected" -LogColor "#FFAA00"
        if ($direct) { Update-UI -Log "Directo $($script:PreferredLang): $direct" -LogColor "#00CCFF" }
        Update-UI -Log "Página oficial: $(Get-DownloadPage -Definition $top -Lang $script:PreferredLang)" -LogColor "#00CCFF"
        Update-UI -Log "Pulsa DESCARGAR FALTANTES para bajarlo a su carpeta." -LogColor "#FFFF00"
    }
    Complete-SQLPrimeWizardStep -Step 'Diagnosticar' -Status Done
}

# ------------------------------------------------------------------------------
# Descarga de los instaladores que faltan, en su carpeta correspondiente.
# ------------------------------------------------------------------------------
function Start-InstallerDownloads {
    # Limpiar restos de descargas anteriores antes de empezar (evita el error
    # "No se puede enlazar el argumento Job porque es null" en el timer).
    if ($script:DownloadJob) {
        $oldJob = Get-Job -Id $script:DownloadJob.Id -ErrorAction SilentlyContinue
        if ($oldJob -and $oldJob.State -eq "Running") {
            Update-UI -Log "Ya hay una descarga en curso. Usa DETENER para cancelarla." -LogColor "#FFAA00"
            return
        }
        if ($oldJob) { Remove-Job -Job $oldJob -Force -ErrorAction SilentlyContinue }
        $script:DownloadJob = $null
    }
    $script:DownloadTimer.Stop()
    $script:DownloadWarningShown = $false

    # Refrescar inventario para no omitir ficheros ya presentes o .part recientes.
    $script:Inventory = Get-InstallerInventory

    $info = $script:DetectedInfo
    $lang = if ($info.LanguageCode) { $info.LanguageCode } elseif ($script:PreferredLang) { $script:PreferredLang } else { "ENU" }
    $major = if ($info.MajorVersion) { $info.MajorVersion } else { "10.50" }

    # Descargar TODAS las versiones faltantes con URL directa verificada
    # (ambas familias 10.0 y 10.50), no solo los SP superiores al actual.
    $defs = @($script:SPDefinitions | Sort-Object Major, SPNumber)

    $script:DownloadOperationId = if (Get-Command New-SQLPrimeOperationId -ErrorAction SilentlyContinue) { New-SQLPrimeOperationId } else { [guid]::NewGuid().ToString() }
    Update-UI -Log "=== DESCARGAR INSTALADORES FALTANTES ($lang) === [op:$($script:DownloadOperationId)]" -LogColor "#FF00FF"
    try { if (Get-Command Write-SQLPrimeStructuredLog -ErrorAction SilentlyContinue) { Write-SQLPrimeStructuredLog -Level INFO -Component 'download' -OperationId $script:DownloadOperationId -Message 'Download operation started' -Data @{ lang=$lang; major=$major } } } catch { }

    # Construcción de objetivos: usa módulo Download si está disponible (Fase 0).
    $targetPlan = $null
    if (Get-Command Get-SQLPrimeDownloadTargets -ErrorAction SilentlyContinue) {
        $targetPlan = Get-SQLPrimeDownloadTargets -Definitions $defs -Lang $lang -BaseDir $PSScriptRoot -Inventory $script:Inventory -KnownSizes $script:KnownSizes `
            -GetDirectUrl { param($d,$a,$l) Get-DirectUrl -Definition $d -Arch $a -Lang $l } `
            -GetExpectedFileName { param($maj,$sp,$a,$l) Get-ExpectedFileName -MajorVersion $maj -SPNumber $sp -Arch $a -Lang $l }
    }

    $targets = @()
    $missingNoDirect = @()
    if ($targetPlan) {
        foreach ($n in @($targetPlan.AlreadyPresent)) { Update-UI -Log "[OK] Ya existe: $n" -LogColor "#00FF00" }
        foreach ($n in @($targetPlan.MissingNoDirect)) {
            $missingNoDirect += $n
            Update-UI -Log "[SIN URL DIRECTA] $n - usa el catálogo/enlace del informe." -LogColor "#FFAA00"
        }
        foreach ($t in @($targetPlan.Targets)) {
            # Mover final incompleto a .part para reanudar (comportamiento existente).
            if ($t.IncompleteFinal -and (Test-Path -LiteralPath $t.FinalPath)) {
                try {
                    $actual = (Get-Item -LiteralPath $t.FinalPath).Length
                    Move-Item -LiteralPath $t.FinalPath -Destination $t.Path -Force -ErrorAction Stop
                    $t.ResumeBytes = [int64](Get-Item -LiteralPath $t.Path).Length
                    Update-UI -Log "Fichero incompleto detectado ($([math]::Round($actual / 1MB, 1)) MB); se reanudará: $($t.Name)" -LogColor "#FFFF00"
                } catch {
                    Update-UI -Log "No se pudo marcar '$($t.Name)' como parcial (puede estar en uso): $($_.Exception.Message)" -LogColor "#FF0000"
                    continue
                }
            }
            if (Test-Path -LiteralPath $t.Path) { $t.ResumeBytes = [int64](Get-Item -LiteralPath $t.Path).Length }
            $expectedHash = $null
            try { if (Get-Command Get-SQLPrimeKnownHash -ErrorAction SilentlyContinue) { $expectedHash = Get-SQLPrimeKnownHash -Name $t.Name } } catch { }
            $targets += [pscustomobject]@{
                Name=$t.Name; Url=$t.Url; Path=$t.Path; FinalPath=$t.FinalPath; Dir=$t.Dir; SP=$t.SP;
                ResumeBytes=$t.ResumeBytes; ExpectedSize=$t.ExpectedSize; ExpectedSha256=$expectedHash
            }
            if ($t.ResumeBytes -gt 0) {
                Update-UI -Log "Pendiente: $($t.Name) -> $($t.Dir) (REANUDAR desde $([math]::Round($t.ResumeBytes / 1MB, 1)) MB)" -LogColor "#FFFF00"
            } else {
                Update-UI -Log "Pendiente: $($t.Name) -> $($t.Dir) (nueva)" -LogColor "#FFFF00"
            }
        }
    } else {
        # Fallback legacy si el módulo Download no está cargado.
        foreach ($def in $defs) {
            $family = if ($def.Major -eq "10.50") { "SQLServer2008R2" } else { "SQLServer2008" }
            foreach ($arch in @("x64", "x86")) {
                $url = Get-DirectUrl -Definition $def -Arch $arch -Lang $lang
                $name = Get-ExpectedFileName -MajorVersion $def.Major -SPNumber $def.SPNumber -Arch $arch -Lang $lang
                $sameFile = @($script:Inventory | Where-Object { $_.Major -eq $def.Major -and $_.SPNumber -eq $def.SPNumber -and $_.Arch -eq $arch -and $_.Lang -eq $lang })
                $versionFolder = if ($def.Major -eq "10.50") { "SQL Server 2008 R2 (10.50)" } else { "SQL Server 2008 (10.0)" }
                $installersRoot = Join-Path $PSScriptRoot "Instaladores"
                $structuredDir = Join-Path $installersRoot "$versionFolder\ServicePacks\SP$($def.SPNumber)\$arch\$lang"
                $sameSP = @($script:Inventory | Where-Object { $_.Major -eq $def.Major -and $_.SPNumber -eq $def.SPNumber })
                $folderPath = if ($sameFile.Count -gt 0) { $sameFile[0].FolderPath } elseif (Test-Path -LiteralPath $structuredDir) { $structuredDir } elseif ($sameSP.Count -gt 0) { $sameSP[0].FolderPath } else { Join-Path $installersRoot "$($family)SP$($def.SPNumber)" }
                $finalPath = Join-Path $folderPath $name
                $partPath  = "$finalPath.part"
                $expectedSize = Get-KnownSize -Name $name
                if (Test-Path -LiteralPath $finalPath) {
                    $actual = (Get-Item -LiteralPath $finalPath).Length
                    if ($expectedSize -gt 0 -and $actual -lt $expectedSize) {
                        try { Move-Item -LiteralPath $finalPath -Destination $partPath -Force -ErrorAction Stop; Update-UI -Log "Fichero incompleto detectado ($([math]::Round($actual / 1MB, 1)) MB); se reanudará: $name" -LogColor "#FFFF00" }
                        catch { Update-UI -Log "No se pudo marcar '$name' como parcial: $($_.Exception.Message)" -LogColor "#FF0000"; continue }
                    } else { Update-UI -Log "[OK] Ya existe: $finalPath" -LogColor "#00FF00"; continue }
                }
                if (-not $url) { $missingNoDirect += $name; Update-UI -Log "[SIN URL DIRECTA] $name - usa el catálogo/enlace del informe." -LogColor "#FFAA00"; continue }
                $resumeBytes = 0
                if (Test-Path -LiteralPath $partPath) { $resumeBytes = [int64](Get-Item -LiteralPath $partPath).Length }
                $expectedHash = $null
                try { if (Get-Command Get-SQLPrimeKnownHash -ErrorAction SilentlyContinue) { $expectedHash = Get-SQLPrimeKnownHash -Name $name } } catch { }
                $targets += [pscustomobject]@{ Name=$name; Url=$url; Path=$partPath; FinalPath=$finalPath; Dir=$folderPath; SP=$def.SP; ResumeBytes=$resumeBytes; ExpectedSize=$expectedSize; ExpectedSha256=$expectedHash }
                if ($resumeBytes -gt 0) { Update-UI -Log "Pendiente: $name -> $folderPath (REANUDAR desde $([math]::Round($resumeBytes / 1MB, 1)) MB)" -LogColor "#FFFF00" } else { Update-UI -Log "Pendiente: $name -> $folderPath (nueva)" -LogColor "#FFFF00" }
            }
        }
    }
    if ($missingNoDirect.Count -gt 0) {
        Update-UI -Log "Faltan $($missingNoDirect.Count) fichero(s) sin URL directa verificada; revisa INVENTARIO / DESCARGAS para los enlaces oficiales." -LogColor "#FFAA00"
    }

    # Centro de descargas Pro: persistir la cola y conservar pausas entre sesiones.
    if ($targets.Count -gt 0 -and (Get-Command Initialize-SQLPrimeDownloadQueue -ErrorAction SilentlyContinue)) {
        try {
            $script:DownloadQueuePath = Initialize-SQLPrimeDownloadQueue -Targets $targets -BaseDir $PSScriptRoot
            Update-UI -Log "[COLA] $($targets.Count) archivo(s) persistidos en logs\download_queue.json (velocidad/ETA por archivo)." -LogColor '#00CCFF'
        } catch {
            Update-UI -Log "No se pudo persistir la cola de descargas: $($_.Exception.Message)" -LogColor '#FFAA00'
        }
    }

    if ($targets.Count -eq 0) {
        Update-UI -Log "No faltan instaladores $lang con URL directa verificada, o ya están presentes." -LogColor "#00FF00"
        $TxtDownloadStatus.Text = "No hay descargas pendientes. Todos los instaladores con URL directa verificada están presentes."
        $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Visible
        $ProgressBar.Value = 0
        $TxtProgress.Text = "0%"
        return
    }

    $script:DownloadResults = @()
    $script:DownloadTotal = $targets.Count
    $script:DownloadCurrentFile = ""
    $script:DownloadCurrentBytes = 0
    $script:DownloadCurrentTotal = 0
    $ProgressBar.Value = 5
    $TxtProgress.Text = "5%"
    $BtnDownload.IsEnabled = $false
    $BtnStopDownload.IsEnabled = $true
    $pendingNames = @($targets | ForEach-Object { $_.Name }) -join " | "
    $TxtDownloadStatus.Text = "En cola ($($targets.Count)): $pendingNames"
    $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Visible

    # Descarga a ".part" con cabecera Range: se puede detener y reanudar.
    $script:DownloadJob = Start-Job -ScriptBlock {
        param($items, $baseDir)

        # Estado de la cola leido desde disco: permite pausar un archivo sin detener el job.
        function Get-QueueState {
            param([string]$Name)
            $path = Join-Path $baseDir 'logs\download_queue.json'
            if (-not (Test-Path -LiteralPath $path)) { return 'Pending' }
            try {
                $queue = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
                $entry = @($queue | Where-Object { $_.Name -eq $Name })[0]
                if ($null -ne $entry) { return [string]$entry.State }
            } catch { }
            return 'Pending'
        }

        foreach ($item in $items) {
            if ((Get-QueueState -Name $item.Name) -in @('Paused', 'Cancelled')) {
                [pscustomobject]@{ Type="RESULT"; Name=$item.Name; Status="PAUSED"; Path=$item.Path; Bytes=[int64]$item.ResumeBytes; Expected=[int64]$item.ExpectedSize; Message="Pausado desde la cola; se reanudara desde .part" }
                continue
            }
            $expectedHash = $null
            try { if ($item.PSObject.Properties.Name -contains 'ExpectedSha256') { $expectedHash = [string]$item.ExpectedSha256 } } catch { }
            $result = [pscustomobject]@{ Type="RESULT"; Name=$item.Name; Status="ERROR"; Path=$item.FinalPath; Bytes=0; Expected=$item.ExpectedSize; Resumed=$false; Sha256=$null; HashChecked=$false; HashOk=$true; Message="" }
            $fs = $null
            $resp = $null
            try {
                if (-not (Test-Path -LiteralPath $item.Dir)) {
                    New-Item -ItemType Directory -Path $item.Dir -Force -ErrorAction Stop | Out-Null
                }
                $start = 0
                if (Test-Path -LiteralPath $item.Path) { $start = [int64](Get-Item -LiteralPath $item.Path).Length }

                $req = [System.Net.HttpWebRequest]::Create($item.Url)
                $req.Timeout = 300000
                $req.ReadWriteTimeout = 300000
                if ($start -gt 0) { $req.AddRange([int64]$start) }
                $resp = $req.GetResponse()

                # Si el servidor ignora Range (200 en vez de 206), se empieza de cero.
                if ($start -gt 0 -and [int]$resp.StatusCode -ne 206) {
                    $resp.Close(); $resp = $null
                    $start = 0
                    Remove-Item -LiteralPath $item.Path -Force -ErrorAction SilentlyContinue
                    $req = [System.Net.HttpWebRequest]::Create($item.Url)
                    $req.Timeout = 300000
                    $req.ReadWriteTimeout = 300000
                    $resp = $req.GetResponse()
                }

                $mode = if ($start -gt 0) { [System.IO.FileMode]::Append } else { [System.IO.FileMode]::Create }
                $fs = [System.IO.File]::Open($item.Path, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
                $stream = $resp.GetResponseStream()
                $buffer = New-Object byte[] 1048576
                $written = $start
                $total = $start + [int64]$resp.ContentLength
                $nextReport = $start + 10485760
                $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                # Emitir progreso inicial para que la UI muestre % inmediatamente (incluye reanudaciones).
                [pscustomobject]@{ Type="PROGRESS"; Name=$item.Name; FileId=$item.Name; Bytes=$written; Total=$total; Ts=$ts; State="Downloading" }

                $paused = $false
                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fs.Write($buffer, 0, $read)
                    $written += $read
                    if ($written -ge $nextReport) {
                        $nextReport = $written + 10485760
                        $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                        [pscustomobject]@{ Type="PROGRESS"; Name=$item.Name; FileId=$item.Name; Bytes=$written; Total=$total; Ts=$ts; State="Downloading" }
                        if ((Get-QueueState -Name $item.Name) -in @('Paused', 'Cancelled')) {
                            $paused = $true
                            break
                        }
                    }
                }
                $fs.Dispose(); $fs = $null
                $resp.Close(); $resp = $null

                if ($paused) {
                    [pscustomobject]@{ Type="RESULT"; Name=$item.Name; Status="PAUSED"; Path=$item.Path; Bytes=[int64]$written; Expected=[int64]$total; Message="Pausado a peticion del usuario; .part conservado" }
                    continue
                }

                $len = [int64](Get-Item -LiteralPath $item.Path).Length
                if ($item.ExpectedSize -gt 0 -and $len -ne [int64]$item.ExpectedSize) {
                    throw "Tamaño incorrecto: $len bytes (esperado $($item.ExpectedSize)). Se conserva el .part para reanudar."
                }
                if ($len -lt 1000000) { throw "Fichero demasiado pequeño ($len bytes)." }
                Move-Item -LiteralPath $item.Path -Destination $item.FinalPath -Force -ErrorAction Stop

                # Fase 0: calcular SHA256 y verificar si hay hash esperado.
                $sha = [System.Security.Cryptography.SHA256]::Create()
                $hs = [System.IO.File]::OpenRead($item.FinalPath)
                try { $result.Sha256 = ([BitConverter]::ToString($sha.ComputeHash($hs)) -replace '-','').ToLowerInvariant() }
                finally { $hs.Dispose(); $sha.Dispose() }
                if ($expectedHash -and $expectedHash.Length -eq 64) {
                    $result.HashChecked = $true
                    $result.HashOk = ($result.Sha256 -eq $expectedHash.ToLowerInvariant())
                    if (-not $result.HashOk) {
                        throw "SHA256 incorrecto: esperado $expectedHash, obtenido $($result.Sha256)."
                    }
                }

                $result.Status = "OK"
                $result.Bytes = $len
                $result.Resumed = ($start -gt 0)
            } catch {
                $result.Message = $_.Exception.Message
            } finally {
                if ($fs) { $fs.Dispose() }
                if ($resp) { $resp.Close() }
            }
            $result
        }
    } -ArgumentList (, $targets), $PSScriptRoot

    # El handler se define una sola vez (ver $script:DownloadTimerTick).
    # Solo se registra en el timer la primera vez; asi no se acumulan
    # handlers al iniciar/detener y nunca se usa un Job nulo.
    Register-DownloadTimerTick
    $script:DownloadTimer.Start()
    Update-UI -Log "Descarga en segundo plano iniciada ($($targets.Count) ficheros). Pulsa DETENER para cancelar." -LogColor "#00CCFF"
}

function Stop-InstallerDownloads {
    if (-not $script:DownloadJob) {
        Update-UI -Log "No hay ninguna descarga en curso." -LogColor "#FFAA00"
        return
    }
    $job = Get-Job -Id $script:DownloadJob.Id -ErrorAction SilentlyContinue
    if ($job) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    $script:DownloadJob = $null
    # No se desuscribe el handler: es unico y se reutiliza en la proxima descarga.
    $script:DownloadTimer.Stop()
    $BtnDownload.IsEnabled = $true
    $BtnStopDownload.IsEnabled = $false
    $TxtDownloadStatus.Text = "Descarga detenida. Los ficheros .part se conservan para reanudar."
    $TxtDownloadStatus.Visibility = [System.Windows.Visibility]::Visible
    $script:DownloadCurrentFile = ""
    if (-not $script:DownloadWarningShown) {
        $script:DownloadWarningShown = $true
        Update-UI -Log "AVISO: existe una descarga incompleta (.part). Al pulsar DESCARGAR FALTANTES se continuará desde el último byte." -LogColor "#FFAA00"
    }
}

# ------------------------------------------------------------------------------
# Reparación del servicio SQL tras el fallo de upgrade de master (5597/912/3417).
# ------------------------------------------------------------------------------
# Exporta la clave FILESTREAM. reg.exe necesita "HKLM\..." (sin los dos puntos
# del proveedor de PowerShell); si falla, se genera un .reg equivalente a mano.
function Export-RegistryKeyBackup {
    param([string]$ProviderKey, [string]$BackupPath)

    $regStyleKey = $ProviderKey -replace '^HKLM:\\', 'HKLM\'
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & reg.exe export $regStyleKey $BackupPath /y 2>&1
    $ErrorActionPreference = $oldPreference
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $BackupPath)) {
        return $BackupPath
    }

    try {
        $key = Get-Item -LiteralPath $ProviderKey -ErrorAction Stop
        $hivePath = $ProviderKey -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('Windows Registry Editor Version 5.00')
        $lines.Add('')
        $lines.Add("[$hivePath]")
        foreach ($name in $key.GetValueNames()) {
            $value = $key.GetValue($name)
            switch ($key.GetValueKind($name)) {
                'DWord' {
                    $lines.Add("`"$name`"=dword:$('{0:X8}' -f [uint32]$value)")
                }
                'String' {
                    $escaped = $value -replace '\\', '\\\\' -replace '"', '\"'
                    $lines.Add("`"$name`"=`"$escaped`"")
                }
                'ExpandString' {
                    $bytes = [System.Text.Encoding]::Unicode.GetBytes("$value`0")
                    $lines.Add("`"$name`"=hex(2):$([System.BitConverter]::ToString($bytes).Replace('-', ',').ToLower())")
                }
                'MultiString' {
                    $bytes = [System.Text.Encoding]::Unicode.GetBytes((($value -join "`0") + "`0`0"))
                    $lines.Add("`"$name`"=hex(7):$([System.BitConverter]::ToString($bytes).Replace('-', ',').ToLower())")
                }
                'Binary' {
                    $lines.Add("`"$name`"=hex:$([System.BitConverter]::ToString($value).Replace('-', ',').ToLower())")
                }
                default {
                    $lines.Add("; $name (tipo $($key.GetValueKind($name))) no exportado")
                }
            }
        }
        $lines -join "`r`n" | Set-Content -LiteralPath $BackupPath -Encoding Unicode -Force
        return $BackupPath
    } catch {
        return $null
    }
}

# Get-SQLServiceCandidates / Get-SQLServiceStates movidos a modules/Services.ps1 (Fase 0).

# Inicia TODOS los servicios relacionados con SQL Server: motor, Agent,
# FILESTREAM, Browser, VSS Writer, SSAS, SSRS, SSIS y Distributed Replay.
function Start-AllSQLServices {
    param([string]$Instance, [string]$InstanceId)

    $candidates = @(Get-SQLServiceCandidates -Instance $Instance)
    $total = $candidates.Count
    $idx = 0
    $started = 0
    $already = 0
    $failed = @()
    $toStart = @()
    $startTimeout = if ($script:Options -and $script:Options.StartTimeoutSec) { [int]$script:Options.StartTimeoutSec } else { 30 }
    $retries = if ($script:Options -and $script:Options.RetryCount) { [int]$script:Options.RetryCount } else { 2 }
    $pollMs = Get-SQLPrimePollMs
    $fast = (-not $script:Options) -or ($script:Options.FastMode -ne $false)
    $sim = Test-SQLPrimeSimulation
    $modeLabel = if ($fast) { 'RÁPIDO' } else { 'SEGURO' }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $script:OperationStopwatch = $sw

    Write-SQLPrimeLog -Level STEP -Message "INICIO DE SERVICIOS [$modeLabel] | instancia=$Instance | candidatos=$total | timeout=${startTimeout}s | reintentos=$retries | sondeo=${pollMs}ms"
    if ($sim) { Write-SQLPrimeLog -Level WARN -Message 'SIMULACIÓN ACTIVA: no se cambiará ningún servicio.' }

    if ($script:Options -and $script:Options.ReportBeforeAfter) {
        Save-SQLPrimeSnapshot -Phase 'ANTES' -Instance $Instance
    }

    # Una sola consulta al Service Control Manager para decidir qué falta.
    $states = Get-SQLServiceStates -Instance $Instance
    $installedCount = @($states.Keys).Count
    Write-SQLPrimeLog -Level INFO -Message "Estado inicial: $installedCount de $total servicios instalados; $($total - $installedCount) omitidos."

    # Fase de decision: se omite la espera por servicio (Bloque G).
    foreach ($name in $candidates) {
        if ($script:ProgressCancelled) {
            Update-UI -Log 'Operación cancelada por el usuario.' -LogColor '#FFAA00'
            Update-ServiceProgressModal -Service 'CANCELADO' -Status 'por el usuario' -Done $idx -Total $total -Color '#FFAA00'
            break
        }
        $idx++
        Update-ServiceProgressModal -Service $name -Status 'iniciando...' -Done ($idx - 1) -Total $total -Color '#FFFF00'
        $svc = $states[$name]
        if (-not $svc) {
            Write-SQLPrimeLog -Level DEBUG -Message "$name no está instalado; se omite."
            Update-ServiceProgressModal -Service $name -Status 'no instalado' -Done $idx -Total $total -Color '#666666'
            continue
        }
        if ($svc.Status -eq "Running") {
            $already++
            Update-UI -Log "  ✓ $name ya está en ejecución." -LogColor "#00FF00"
            Write-SQLPrimeLog -Level OK -Message "$name ya estaba Running (sin cambios)."
            Update-ServiceProgressModal -Service $name -Status 'ya activo' -Done $idx -Total $total -Color '#00FF00'
            continue
        }
        if ($sim) {
            $started++
            Update-UI -Log "  [SIMULACIÓN] $name se habilitaría y arrancaría (sin cambios reales)." -LogColor '#FF00FF'
            Write-SQLPrimeLog -Level CMD -Message "[SIM] Start-Service -Name $name"
            Update-ServiceProgressModal -Service $name -Status 'simulado' -Done $idx -Total $total -Color '#FF00FF'
            continue
        }
        $toStart += $name
    }

    if (-not $sim -and $toStart.Count -gt 0) {
        # Fase 1/2: emitir TODAS las ordenes antes de esperar. El SCM solapa
        # los arranques y se ahorra una espera de hasta 30s por servicio.
        Write-SQLPrimeLog -Level INFO -Message "Fase 1/2: emitiendo $($toStart.Count) solicitudes de arranque sin espera intermedia."
        foreach ($name in $toStart) {
            if ($script:ProgressCancelled) { break }
            $svc = $states[$name]
            $svcSw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                if ($svc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) {
                    Write-SQLPrimeLog -Level CMD -Message "Set-Service -Name $name -StartupType Automatic"
                    Set-Service -Name $name -StartupType Automatic -ErrorAction Stop
                    Update-UI -Log "  • $name habilitado (Automatic)." -LogColor "#FFFF00"
                    Write-SQLPrimeLog -Level OK -Message "$name habilitado (Automatic)."
                }
                $issued = $false
                for ($attempt = 1; $attempt -le ($retries + 1) -and -not $issued; $attempt++) {
                    if ($attempt -gt 1) {
                        Write-SQLPrimeLog -Level WARN -Message "Reintento $attempt/$($retries + 1) para $name."
                        Start-Sleep -Milliseconds ([Math]::Min(2000, $attempt * 500))
                    }
                    Write-SQLPrimeLog -Level CMD -Message "Start-Service -Name $name (intento $attempt)"
                    Start-Service -Name $name -ErrorAction Stop
                    $issued = $true
                }
                Write-SQLPrimeLog -Level DEBUG -Message "$name solicitud enviada en $($svcSw.ElapsedMilliseconds) ms."
            } catch {
                $svcSw.Stop()
                $failed += $name
                Update-UI -Log "  ⚠ No se pudo iniciar $name : $($_.Exception.Message)" -LogColor "#FF0000"
                Write-SQLPrimeLog -Level ERROR -Message "$name no se pudo iniciar: $($_.Exception.Message) ($($svcSw.ElapsedMilliseconds) ms)"
                Update-ServiceProgressModal -Service $name -Status 'incidencia' -Done $idx -Total $total -Color '#FF0000'
                Update-UI -Log (Get-SQLPrimeServiceDiagnostic -Name $name) -LogColor '#FFAA00'
            }
        }

        # Fase 2/2: una sola espera para TODOS los servicios pendientes.
        $pending = @($toStart | Where-Object { $failed -notcontains $_ })
        if ($pending.Count -gt 0) {
            Write-SQLPrimeLog -Level INFO -Message "Fase 2/2: esperando a $($pending.Count) servicios durante $startTimeout s (sondeo ${pollMs} ms)."
            $deadline = (Get-Date).AddSeconds($startTimeout)
            while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline -and -not $script:ProgressCancelled) {
                $still = @()
                foreach ($name in $pending) {
                    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
                    if (-not $svc -or $svc.Status -eq "Running") { } else { $still += $name }
                }
                $pending = $still
                if ($pending.Count -eq 0) { break }
                Start-Sleep -Milliseconds $pollMs
                Pump-UI
            }
        }

        $doneIdx = 0
        foreach ($name in $toStart) {
            $doneIdx++
            if ($failed -contains $name) { continue }
            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") {
                $started++
                Update-UI -Log "  ✓ $name iniciado." -LogColor "#00FF00"
                Write-SQLPrimeLog -Level OK -Message "$name Running."
                Update-ServiceProgressModal -Service $name -Status 'en ejecución' -Done ($idx - $toStart.Count + $doneIdx) -Total $total -Color '#00FF00'
            } else {
                $failed += $name
                $state = if ($svc) { [string]$svc.Status } else { 'NO INSTALADO' }
                Update-UI -Log "  ⚠ $name no llegó a arrancar tras $($retries + 1) intentos (estado: $state)." -LogColor "#FF0000"
                Write-SQLPrimeLog -Level ERROR -Message "$name no alcanzó Running (estado $state) tras $($retries + 1) intentos."
                Update-ServiceProgressModal -Service $name -Status 'incidencia' -Done ($idx - $toStart.Count + $doneIdx) -Total $total -Color '#FF0000'
                Update-UI -Log (Get-SQLPrimeServiceDiagnostic -Name $name) -LogColor '#FFAA00'
            }
        }
    }

    if ($script:Options -and $script:Options.ReportBeforeAfter) {
        Save-SQLPrimeSnapshot -Phase 'DESPUES' -Instance $Instance
        Write-SQLPrimeStateDiff -Instance $Instance
    }
    Update-ServiceProgressModal -Service 'COMPLETADO' -Status "$started iniciados, $already ya activos, $($failed.Count) incidencias" -Done $total -Total $total -Color '#00FFFF'
    Update-UI -Log "RESUMEN DE SERVICIOS: $started iniciados, $already ya activos, $($failed.Count) con incidencia." -LogColor "#00CCFF"
    Write-SQLPrimeLog -Level TIME -Message "INICIO FINALIZADO en $(([math]::Round($sw.Elapsed.TotalSeconds, 2)).ToString('0.00')) s | $started arrancados | $already ya activos | $($failed.Count) incidencias"
    $script:OperationStopwatch = $null
    if ($failed.Count -gt 0) {
        Update-UI -Log "Servicios con incidencia: $($failed -join ', ')" -LogColor "#FFAA00"
    }
    return $failed
}

# Verificación final: comprueba uno por uno TODOS los servicios SQL instalados.
function Test-AllSQLServices {
    param(
        [string]$Instance,
        [ValidateSet('Running', 'Stopped')][string]$ExpectedState = 'Running'
    )

    $candidates = @(Get-SQLServiceCandidates -Instance $Instance)
    $total = $candidates.Count
    $idx = 0
    $installed = 0
    $ok = 0
    $bad = @()
    $states = Get-SQLServiceStates -Instance $Instance
    Write-SQLPrimeLog -Level STEP -Message "VERIFICACIÓN FINAL | esperado=$ExpectedState | candidatos=$total"

    foreach ($name in $candidates) {
        $idx++
        $svc = $states[$name]
        if (-not $svc) {
            Write-SQLPrimeLog -Level DEBUG -Message "$name no instalado; se omite de la verificación."
            Update-ServiceProgressModal -Service $name -Status 'no instalado' -Done $idx -Total $total -Color '#666666'
            continue
        }
        $installed++
        if ($svc.Status -eq $ExpectedState) {
            $ok++
            Update-UI -Log "  ✓ $name = $($svc.Status)" -LogColor "#00FF00"
            Write-SQLPrimeLog -Level OK -Message "VERIFICADO $name = $($svc.Status)"
            Update-ServiceProgressModal -Service $name -Status "verificado: $($svc.Status)" -Done $idx -Total $total -Color '#00FF00'
        } else {
            $bad += "$name ($($svc.Status))"
            Update-UI -Log "  ✗ $name = $($svc.Status) [esperado $ExpectedState]" -LogColor "#FF0000"
            Write-SQLPrimeLog -Level ERROR -Message "VERIFICACIÓN FALLIDA $name = $($svc.Status) (esperado $ExpectedState)"
            Update-ServiceProgressModal -Service $name -Status "incidencia: $($svc.Status)" -Done $idx -Total $total -Color '#FF0000'
        }
    }

    Update-ServiceProgressModal -Service 'VERIFICACIÓN FINAL' -Status "$ok de $installed servicios $ExpectedState" -Done $total -Total $total -Color '#00FFFF'
    Write-SQLPrimeLog -Level INFO -Message "Verificación completada: $ok de $installed servicios en $ExpectedState; $($bad.Count) incidencias."
    Update-UI -Log "VERIFICACIÓN FINAL: $ok de $installed servicios SQL están $ExpectedState." -LogColor "#00CCFF"
    if ($bad.Count -eq 0) {
        Update-UI -Log "✅ TODOS los servicios SQL instalados están $ExpectedState." -LogColor "#00FF00"
    } else {
        Update-UI -Log "⚠ Servicios fuera del estado esperado: $($bad -join ', ')" -LogColor "#FFAA00"
    }
    return $bad
}

# Detiene y desactiva TODOS los servicios SQL instalados en el servidor.
function Stop-AllSQLServices {
    $info = $script:DetectedInfo
    if (-not $info.Instance) {
        Update-UI -Log "No hay instancia detectada; pulsa primero REFRESCAR ESTADO." -LogColor "#FF0000"
        return
    }

    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Update-UI -Log "Se necesitan permisos de administrador para desactivar servicios." -LogColor "#FF0000"
        return
    }

    $instance = $info.Instance
    $msg = "Se van a DETENER y DESACTIVAR (inicio = Disabled) TODOS los servicios SQL Server instalados:`n`n" +
           "• Motor SQL Server, SQL Agent y FILESTREAM`n" +
           "• SQL Browser y SQL VSS Writer`n" +
           "• SSAS, SSRS, SSIS y Distributed Replay`n`n" +
           "Podrás reactivarlos todos con 🔧 REPARAR SERVICIOS SQL."
    if (-not (Show-SQLPrimeTypedConfirmation -Word 'DESACTIVAR' -Title 'CONFIRMACIÓN DE SEGURIDAD' -Message $msg)) {
        Update-UI -Log "Desactivación de servicios cancelada por el usuario." -LogColor "#FFAA00"
        return
    }
    if ($script:Options -and $script:Options.RestorePointOnStop) {
        $null = New-SQLPrimeRestorePoint -Reason 'antes de desactivar servicios SQL'
    }

    # Se detienen primero los dependientes (Agent, FILESTREAM, SSRS...) y el motor al final.
    $candidates = @(Get-SQLServiceCandidates -Instance $instance)
    [Array]::Reverse($candidates)
    $total = $candidates.Count
    $stopTimeout = if ($script:Options -and $script:Options.StopTimeoutSec) { [int]$script:Options.StopTimeoutSec } else { 20 }
    $pollMs = Get-SQLPrimePollMs
    $sim = Test-SQLPrimeSimulation
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $script:OperationStopwatch = $sw

    Show-ServiceProgressModal -Title 'DESACTIVANDO SERVICIOS SQL' -Subtitle "Instancia: $instance" -Total $total
    try {
        Update-UI -Log "=== DESACTIVANDO TODOS LOS SERVICIOS SQL ===" -LogColor "#FF00FF"
        Write-SQLPrimeLog -Level STEP -Message "DESACTIVACIÓN RÁPIDA | instancia=$instance | candidatos=$total (orden inverso) | timeout=${stopTimeout}s | sondeo=${pollMs}ms"
        if ($sim) { Write-SQLPrimeLog -Level WARN -Message 'SIMULACIÓN ACTIVA: no se cambiará ningún servicio.' }

        $stopped = 0
        $already = 0
        $failed = @()
        $toStop = @()
        $idx = 0
        if ($script:Options -and $script:Options.ReportBeforeAfter) { Save-SQLPrimeSnapshot -Phase 'ANTES' -Instance $instance }
        $states = Get-SQLServiceStates -Instance $instance
        Write-SQLPrimeLog -Level INFO -Message "Estado inicial: $(@($states.Keys).Count) servicios instalados."

        # Fase 1/2: emitir TODOS los Stop-Service y Disabled sin espera intermedia.
        Write-SQLPrimeLog -Level INFO -Message "Fase 1/2: emitiendo paradas en orden inverso sin espera intermedia."
        foreach ($name in $candidates) {
            if ($script:ProgressCancelled) {
                Update-UI -Log 'Operación cancelada por el usuario.' -LogColor '#FFAA00'
                Update-ServiceProgressModal -Service 'CANCELADO' -Status 'por el usuario' -Done $idx -Total $total -Color '#FFAA00'
                break
            }
            $idx++
            Update-ServiceProgressModal -Service $name -Status 'deteniendo...' -Done ($idx - 1) -Total $total -Color '#FFFF00'
            $svc = $states[$name]
            if (-not $svc) {
                Write-SQLPrimeLog -Level DEBUG -Message "$name no está instalado; se omite."
                Update-ServiceProgressModal -Service $name -Status 'no instalado' -Done $idx -Total $total -Color '#666666'
                continue
            }
            if ($svc.Status -eq 'Stopped') {
                $already++
                Update-UI -Log "  • $name ya estaba detenido." -LogColor '#888888'
                Write-SQLPrimeLog -Level OK -Message "$name ya estaba Stopped."
                Update-ServiceProgressModal -Service $name -Status 'ya detenido' -Done $idx -Total $total -Color '#888888'
                continue
            }
            if ($sim) {
                $stopped++
                Update-UI -Log "  [SIMULACIÓN] $name se detendría y desactivaría (sin cambios reales)." -LogColor '#FF00FF'
                Write-SQLPrimeLog -Level CMD -Message "[SIM] Stop-Service -Name $name -Force; Set-Service -Name $name -StartupType Disabled"
                Update-ServiceProgressModal -Service $name -Status 'simulado' -Done $idx -Total $total -Color '#FF00FF'
                continue
            }
            $svcSw = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                Write-SQLPrimeLog -Level CMD -Message "Stop-Service -Name $name -Force"
                Stop-Service -Name $name -Force -ErrorAction Stop
                Write-SQLPrimeLog -Level CMD -Message "Set-Service -Name $name -StartupType Disabled"
                Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
                $toStop += $name
                Write-SQLPrimeLog -Level DEBUG -Message "$name parada solicitada en $($svcSw.ElapsedMilliseconds) ms."
            } catch {
                $svcSw.Stop()
                $failed += $name
                Update-UI -Log "  ⚠ No se pudo desactivar $name : $($_.Exception.Message)" -LogColor "#FF0000"
                Write-SQLPrimeLog -Level ERROR -Message "$name no se pudo desactivar: $($_.Exception.Message)"
                Update-ServiceProgressModal -Service $name -Status 'incidencia' -Done $idx -Total $total -Color '#FF0000'
                Update-UI -Log (Get-SQLPrimeServiceDiagnostic -Name $name) -LogColor '#FFAA00'
            }
        }

        # Fase 2/2: una sola espera para todas las paradas emitidas.
        $pending = @($toStop | Where-Object { $failed -notcontains $_ })
        if ($pending.Count -gt 0) {
            Write-SQLPrimeLog -Level INFO -Message "Fase 2/2: esperando a $($pending.Count) servicios durante $stopTimeout s (sondeo ${pollMs} ms)."
            $deadline = (Get-Date).AddSeconds($stopTimeout)
            while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline -and -not $script:ProgressCancelled) {
                $still = @()
                foreach ($name in $pending) {
                    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
                    if (-not $svc -or $svc.Status -eq 'Stopped') { } else { $still += $name }
                }
                $pending = $still
                if ($pending.Count -eq 0) { break }
                Start-Sleep -Milliseconds $pollMs
                Pump-UI
            }
        }

        $doneIdx = 0
        foreach ($name in $toStop) {
            $doneIdx++
            if ($failed -contains $name) { continue }
            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
            if (-not $svc -or $svc.Status -eq 'Stopped') {
                $stopped++
                Update-UI -Log "  ⛔ $name detenido y desactivado." -LogColor "#FFAA00"
                Write-SQLPrimeLog -Level OK -Message "$name Stopped + Disabled."
                Update-ServiceProgressModal -Service $name -Status 'detenido y desactivado' -Done ($idx - $toStop.Count + $doneIdx) -Total $total -Color '#FFAA00'
            } else {
                $failed += $name
                Update-UI -Log "  ⚠ $name no llegó a detenerse (estado: $($svc.Status))." -LogColor "#FF0000"
                Write-SQLPrimeLog -Level ERROR -Message "$name no alcanzó Stopped (estado $($svc.Status))."
                Update-ServiceProgressModal -Service $name -Status "incidencia: $($svc.Status)" -Done ($idx - $toStop.Count + $doneIdx) -Total $total -Color '#FF0000'
            }
        }

        if ($script:Options -and $script:Options.ReportBeforeAfter) {
            Save-SQLPrimeSnapshot -Phase 'DESPUES' -Instance $instance
            Write-SQLPrimeStateDiff -Instance $instance
        }
        Update-UI -Log "RESUMEN: $stopped detenidos/desactivados, $already ya estaban detenidos, $($failed.Count) con incidencia." -LogColor "#00CCFF"
        Write-SQLPrimeLog -Level TIME -Message "DESACTIVACIÓN FINALIZADA en $(([math]::Round($sw.Elapsed.TotalSeconds, 2)).ToString('0.00')) s | $stopped detenidos | $already ya detenidos | $($failed.Count) incidencias"
        $script:OperationStopwatch = $null
        $null = Test-AllSQLServices -Instance $instance -ExpectedState 'Stopped'
    } finally {
        Close-ServiceProgressModal
    }
    Refresh-Detection
}

function Repair-SQLService {
    $info = $script:DetectedInfo
    if (-not $info.Instance) {
        Update-UI -Log "No hay instancia detectada; pulsa primero REFRESCAR ESTADO." -LogColor "#FF0000"
        return
    }

    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Update-UI -Log "Se necesitan permisos de administrador: cierra la app y ejecútala como Administrador." -LogColor "#FF0000"
        return
    }

    $instance = $info.Instance
    $instanceId = $info.InstanceId
    $svcName = if ($instance -ieq "MSSQLSERVER") { "MSSQLSERVER" } else { "MSSQL`$$instance" }
    $agentName = if ($instance -ieq "MSSQLSERVER") { "SQLSERVERAGENT" } else { "SQLSERVERAGENT`$$instance" }

    Update-UI -Log "=== DIAGNÓSTICO / REPARACIÓN DEL SERVICIO SQL ===" -LogColor "#FF00FF"
    Update-UI -Log "Cadena de errores: 5597 (FILESTREAM no inicializado) -> 912 (sqlagent100_msdb_upgrade.sql) -> 3417 (master irrecuperable)." -LogColor "#FF0000"
    Update-UI -Log "Causa real: el registro tiene EnableLevel=3 pero sp_configure 'filestream_access_level' sigue activo en master; el upgrade se aborta y master no recupera." -LogColor "#FFAA00"

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Update-UI -Log "No se encontró el servicio '$svcName'." -LogColor "#FF0000"
        return
    }
    if ($svc.Status -eq "Running") {
        Update-UI -Log "El motor '$svcName' ya está en ejecución; se omiten los pasos de arranque en monousuario." -LogColor "#00FF00"
        Show-ServiceProgressModal -Title 'REPARANDO SERVICIOS SQL' -Subtitle "Motor ya activo - Instancia: $instance"
        try {
            Update-UI -Log "=== ACTIVANDO TODOS LOS SERVICIOS SQL ===" -LogColor "#00CCFF"
            try {
                Start-AllSQLServices -Instance $instance -InstanceId $instanceId | Out-Null
                Update-UI -Log "--- Verificando que TODOS puedan ejecutarse ---" -LogColor "#00CCFF"
                $null = Test-AllSQLServices -Instance $instance -ExpectedState 'Running'
            } catch {
                Update-UI -Log "Error al activar servicios: $($_.Exception.Message)" -LogColor "#FF0000"
            }
        } finally {
            Close-ServiceProgressModal
        }
        Refresh-Detection
        return
    }

    $msg = "La instancia '$instance' tiene el servicio detenido.`n`nSe hará lo siguiente:`n" +
           "1) Copia de seguridad de la clave de FILESTREAM.`n" +
           "2) Detener los servicios SQL dependientes y cualquier sqlservr.exe de la instancia.`n" +
           "3) Deshabilitar FILESTREAM en Windows (EnableLevel=0).`n" +
           "4) Arrancar sqlservr.exe en monousuario con -T902 para omitir el upgrade.`n" +
           "5) Ejecutar sp_configure 'filestream_access_level', 0 + RECONFIGURE.`n" +
           "6) Iniciar el servicio normalmente (el upgrade se reintentará) y arrancar SQL Agent.`n`n¿Continuar?"
    $answer = [System.Windows.MessageBox]::Show($msg, "Reparar servicio SQL - $instance", "YesNo", "Warning")
    if ($answer -ne "Yes") {
        Update-UI -Log "Reparación del servicio cancelada por el usuario." -LogColor "#FFAA00"
        return
    }

    $setupKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\Setup"
    $binRoot = ""
    if (Test-Path $setupKey) {
        $sp = Get-ItemProperty -Path $setupKey
        $binRoot = "$($sp.SQLBinRoot)"
        if (-not $binRoot -and $sp.SQLPath) { $binRoot = Join-Path "$($sp.SQLPath)" "MSSQL\Binn" }
    }
    if (-not $binRoot) { $binRoot = Join-Path $env:ProgramFiles "Microsoft SQL Server\$instanceId\MSSQL\Binn" }
    $binRoot = $binRoot.TrimEnd('\')
    $sqlservr = Join-Path $binRoot "sqlservr.exe"
    if (-not (Test-Path -LiteralPath $sqlservr)) {
        Update-UI -Log "No se encontró sqlservr.exe en: $sqlservr" -LogColor "#FF0000"
        return
    }

    $sqlcmd = @(
        (Join-Path $env:ProgramFiles "Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $sqlcmd) {
        Update-UI -Log "No se encontró sqlcmd.exe; instala las herramientas de cliente de SQL Server 2008 R2." -LogColor "#FF0000"
        return
    }
    $connectArg = if ($instance -ieq "MSSQLSERVER") { "(local)" } else { "(local)\$instance" }
    # Salida de sqlcmd a ficheros acotados: nunca se acumula en memoria.
    $sqlProbeOut = Join-Path $PSScriptRoot "sqlcmd_probe.txt"
    $sqlFixOut   = Join-Path $PSScriptRoot "sqlcmd_fix.txt"

    Show-ServiceProgressModal -Title 'REPARANDO SERVICIOS SQL' -Subtitle "Instancia: $instance"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $script:OperationStopwatch = $sw
    Write-SQLPrimeLog -Level STEP -Message "REPARACIÓN INICIADA | instancia=$instance | motor=$svcName | sondeo=$(Get-SQLPrimePollMs) ms"
    try {
    if (Test-SQLPrimeSimulation) {
        Update-ServiceProgressModal -Service 'SIMULACIÓN' -Status 'no se modificará nada' -Done 1 -Total 1 -Color '#FF00FF'
        Update-UI -Log '[SIMULACIÓN] Reparación simulada: no se tocará el registro ni se detendrá/iniciará el motor.' -LogColor '#FF00FF'
        Write-SQLPrimeLog -Level WARN -Message 'Reparación simulada: se omiten registro, sqlservr monousuario y sp_configure.'
        $null = Start-AllSQLServices -Instance $instance -InstanceId $instanceId
        $null = Test-AllSQLServices -Instance $instance -ExpectedState 'Running'
        Write-SQLPrimeLog -Level TIME -Message "REPARACIÓN SIMULADA finalizada en $(([math]::Round($sw.Elapsed.TotalSeconds, 2)).ToString('0.00')) s."
        $script:OperationStopwatch = $null
        return
    }
    $fsKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\Filestream"
    if (Test-Path $fsKey) {
        $backup = Join-Path $PSScriptRoot "Backup_Filestream_${instanceId}_$(Get-Date -Format yyyyMMdd_HHmmss).reg"
        $savedBackup = Export-RegistryKeyBackup -ProviderKey $fsKey -BackupPath $backup
        if ($savedBackup) {
            Update-UI -Log "Copia de seguridad de FILESTREAM: $savedBackup" -LogColor "#00CCFF"
        } else {
            Update-UI -Log "AVISO: no se pudo guardar la copia de FILESTREAM; se continúa con la reparación." -LogColor "#FFAA00"
        }
    } else {
        Update-UI -Log "No existe la clave de FILESTREAM ($fsKey); se continúa sin modificar el registro." -LogColor "#FFAA00"
    }

    try {
        Update-ServiceProgressModal -Service 'PASO 1/6' -Status 'copia de seguridad de FILESTREAM' -Done 1 -Total 6 -Color '#00FFFF'
        Update-UI -Log "Deteniendo servicios dependientes de '$svcName'..." -LogColor "#FFFF00"
        Update-ServiceProgressModal -Service 'PASO 2/6' -Status 'deteniendo servicios dependientes' -Done 2 -Total 6 -Color '#00FFFF'
        foreach ($depName in @($agentName, "MSSQLFDLauncher", $svcName)) {
            $dep = Get-Service -Name $depName -ErrorAction SilentlyContinue
            if ($dep -and $dep.Status -ne "Stopped") {
                Stop-Service -Name $depName -Force -ErrorAction SilentlyContinue
                Update-UI -Log "Servicio detenido: $depName" -LogColor "#FFFF00"
            }
        }
        foreach ($p in @(Get-Process -Name sqlservr -ErrorAction SilentlyContinue)) {
            try {
                if ($p.Path -and $p.Path.StartsWith($binRoot, [StringComparison]::OrdinalIgnoreCase)) {
                    Stop-Process -Id $p.Id -Force -ErrorAction Stop
                    Update-UI -Log "Proceso residual sqlservr.exe (PID $($p.Id)) detenido." -LogColor "#FFFF00"
                }
            } catch { }
        }

        Update-ServiceProgressModal -Service 'PASO 3/6' -Status 'deshabilitando FILESTREAM en Windows' -Done 3 -Total 6 -Color '#00FFFF'
        if (Test-Path $fsKey) {
            Set-ItemProperty -Path $fsKey -Name "EnableLevel" -Value 0 -Type DWord -ErrorAction Stop
            Update-UI -Log "FILESTREAM deshabilitado en Windows (EnableLevel=0)." -LogColor "#FFFF00"
        }

        # -NoNewWindow hacia que sqlservr.exe -c volcara TODO el ERRORLOG en la
        # consola de PowerShell y pudiera agotar la memoria del host. Se oculta
        # la ventana y se redirigen stdout/stderr a ficheros.
        $monoOut = Join-Path $PSScriptRoot "sqlservr_mono_stdout.log"
        $monoErr = Join-Path $PSScriptRoot "sqlservr_mono_stderr.log"
        Update-ServiceProgressModal -Service 'PASO 4/6' -Status 'arrancando sqlservr en monousuario' -Done 4 -Total 6 -Color '#00FFFF'
        Update-UI -Log "Arrancando sqlservr.exe -m -c -s$instance -T902 (monousuario, sin upgrade)..." -LogColor "#FFFF00"
        Write-SQLPrimeLog -Level CMD -Message "Start-Process sqlservr.exe -m -c -s$instance -T902 (stdout/stderr redirigidos)"
        $mono = Start-Process -FilePath $sqlservr -ArgumentList "-m -c -s$instance -T902" -WorkingDirectory $binRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput $monoOut -RedirectStandardError $monoErr -ErrorAction Stop
        $null = Wait-SQLPrimeCondition -Condition {
            $mono.HasExited -or ((Test-Path -LiteralPath $monoOut) -and ((Get-Item -LiteralPath $monoOut).Length -gt 0))
        } -TimeoutSec 3 -PollMs (Get-SQLPrimePollMs)
        Write-SQLPrimeLog -Level DEBUG -Message "sqlservr monousuario: señal de arranque detectada en $($sw.Elapsed.TotalSeconds.ToString('0.00')) s."

        $ready = $false
        $deadline = (Get-Date).AddSeconds(45)
        $probeAttempt = 0
        while ((Get-Date) -lt $deadline -and -not $mono.HasExited -and -not $script:ProgressCancelled) {
            $probeAttempt++
            Write-SQLPrimeLog -Level DEBUG -Message "sqlcmd SELECT 1 (sondeo $probeAttempt)"
            $null = & $sqlcmd -S $connectArg -E -l 2 -Q "SELECT 1" -o $sqlProbeOut 2>$null
            if ($LASTEXITCODE -eq 0) { $ready = $true; break }
            Start-Sleep -Milliseconds (Get-SQLPrimePollMs)
            Pump-UI
        }

        if ($ready) {
            Update-ServiceProgressModal -Service 'PASO 5/6' -Status 'aplicando sp_configure en monousuario' -Done 5 -Total 6 -Color '#00FFFF'
            Update-UI -Log "Conectado en monousuario. Restableciendo filestream_access_level=0 en master..." -LogColor "#FFFF00"
            $fixSql = "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'filestream_access_level', 0; RECONFIGURE;"
            $null = & $sqlcmd -S $connectArg -E -l 5 -Q $fixSql -o $sqlFixOut 2>$null
            if ($LASTEXITCODE -eq 0) {
                Update-UI -Log "sp_configure aplicado correctamente." -LogColor "#00FF00"
            } else {
                $detail = if (Test-Path -LiteralPath $sqlFixOut) { (Get-Content -LiteralPath $sqlFixOut -TotalCount 5) -join ' ' } else { '' }
                Update-UI -Log "No se pudo aplicar sp_configure: $detail" -LogColor "#FF0000"
            }
            Write-SQLPrimeLog -Level CMD -Message "sqlcmd SHUTDOWN (monousuario)"
            $null = & $sqlcmd -S $connectArg -E -l 5 -Q "SHUTDOWN" -o $sqlFixOut 2>$null
            $null = Wait-SQLPrimeCondition -Condition { $mono.HasExited } -TimeoutSec 3 -PollMs (Get-SQLPrimePollMs)
            if (-not $mono.HasExited) {
                Write-SQLPrimeLog -Level CMD -Message "Stop-Process -Id $($mono.Id) -Force (monousuario no terminó)"
                Stop-Process -Id $mono.Id -Force -ErrorAction SilentlyContinue
            }
        } else {
            if (-not $mono.HasExited) { Stop-Process -Id $mono.Id -Force -ErrorAction SilentlyContinue }
            Update-UI -Log "No se pudo conectar en monousuario (código de salida $($mono.ExitCode)). Se intentará el arranque normal." -LogColor "#FFAA00"
        }

        Update-ServiceProgressModal -Service 'PASO 6/6' -Status 'iniciando el motor en modo normal' -Done 6 -Total 6 -Color '#00FFFF'
        Update-UI -Log "Iniciando el servicio '$svcName' en modo normal (los scripts de upgrade se reintentarán)..." -LogColor "#FFFF00"
        Write-SQLPrimeLog -Level CMD -Message "Start-Service -Name $svcName (modo normal)"
        Start-Service -Name $svcName -ErrorAction SilentlyContinue
        $running = $false
        $deadline = (Get-Date).AddSeconds(90)
        $engineAttempt = 0
        while ((Get-Date) -lt $deadline -and -not $script:ProgressCancelled) {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") { $running = $true; break }
            if ($svc -and $svc.Status -eq "Stopped") {
                $engineAttempt++
                Write-SQLPrimeLog -Level CMD -Message "Start-Service -Name $svcName (reintento $engineAttempt)"
                try { Start-Service -Name $svcName -ErrorAction SilentlyContinue } catch { }
            }
            Start-Sleep -Milliseconds (Get-SQLPrimePollMs)
            Pump-UI
        }
        if ($running) {
            Update-UI -Log "✓ Motor '$svcName' iniciado correctamente." -LogColor "#00FF00"
        } else {
            Update-UI -Log "El servicio '$svcName' SIGUE detenido. Últimos errores:" -LogColor "#FF0000"
            Get-WinEvent -FilterHashtable @{ LogName='Application'; ProviderName='MSSQLSERVER'; StartTime=(Get-Date).AddMinutes(-10) } -MaxEvents 5 -ErrorAction SilentlyContinue |
                ForEach-Object { Update-UI -Log "  [$($_.TimeCreated.ToString('HH:mm:ss'))] Id=$($_.Id): $(($_.Message -split "`n")[0])" -LogColor "#FFAA00" }
            Update-UI -Log "Si persiste 3417, restaura master desde copia o ejecuta setup.exe /ACTION=REBUILDDATABASE." -LogColor "#FFAA00"
        }

        Update-UI -Log "=== ACTIVANDO TODOS LOS SERVICIOS SQL ===" -LogColor "#00CCFF"
        try {
            $null = Start-AllSQLServices -Instance $instance -InstanceId $instanceId
            Update-UI -Log "--- Verificando que TODOS puedan ejecutarse ---" -LogColor "#00CCFF"
            $null = Test-AllSQLServices -Instance $instance -ExpectedState 'Running'
        } catch {
            Update-UI -Log "Error al activar servicios: $($_.Exception.Message)" -LogColor "#FF0000"
        }

        Update-UI -Log "FILESTREAM queda deshabilitado (registro y sp_configure). Para reactivarlo tras aplicar SP3 usa SQL Server Configuration Manager -> Propiedades de la instancia -> FILESTREAM." -LogColor "#FFFF00"
        $BtnRestart.IsEnabled = $true
        $script:ButtonStates['BtnRestart'] = $true
    } catch {
        Update-UI -Log "Error durante la reparación: $($_.Exception.Message)" -LogColor "#FF0000"
        Update-UI -Log "Revisa el ERRORLOG de SQL y el Visor de eventos." -LogColor "#FFAA00"
    }
    } finally {
        Close-ServiceProgressModal
    }
    Write-SQLPrimeLog -Level TIME -Message "REPARACIÓN FINALIZADA en $(([math]::Round($sw.Elapsed.TotalSeconds, 2)).ToString('0.00')) s."
    $script:OperationStopwatch = $null
    Refresh-Detection
}

# ==============================================================================
# 7. EVENTOS
# ==============================================================================
# Arrastre de la ventana (WindowStyle=None). Se ignora el clic cuando se produce
# sobre un control de la barra (botones CERRAR/TEMA...) INCLUSO si el
# OriginalSource es el TextBlock interior del boton. Antes ese TextBlock hacia
# que se llamara a DragMove y el boton CERRAR no recibia su evento Click.
function Test-TitleBarControlClick {
    param($Source)
    $node = $Source -as [System.Windows.DependencyObject]
    while ($null -ne $node -and $node -ne $TitleBar) {
        if ($node -is [System.Windows.Controls.Control]) { return $true }
        try { $node = [System.Windows.Media.VisualTreeHelper]::GetParent($node) }
        catch { return $false }
    }
    return $false
}

$TitleBar.Add_PreviewMouseLeftButtonDown({
    param($sender, $e)
    if (Test-TitleBarControlClick -Source $e.OriginalSource) { return }
    try { $window.DragMove() } catch { }
})

$BtnTheme.Add_Click({
    $orden = @("Dark", "Light", "Auto")
    $idx = [Array]::IndexOf($orden, $script:CurrentTheme)
    if ($idx -lt 0) { $idx = $orden.Count - 1 }
    $script:CurrentTheme = $orden[($idx + 1) % $orden.Count]
    Apply-Theme -ThemeName $script:CurrentTheme
    Update-ThemeButton
    Save-Config
    Update-UI -Log "Tema cambiado a $($script:ThemeLabels[$script:CurrentTheme])." -LogColor "#00CCFF"
})
$BtnMinimize.Add_Click({ $window.WindowState = 'Minimized' })
$BtnClose.Add_Click({ $window.Close() })

# Atajos de teclado profesionales: Esc cierra, F5 refresca el estado.
$window.Add_PreviewKeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
        $window.Close()
        $e.Handled = $true
    } elseif ($e.Key -eq [System.Windows.Input.Key]::F5) {
        try { Refresh-Detection } catch { }
        $e.Handled = $true
    }
})

$window.Add_Closed({
    if ($script:LightsTimer) { $script:LightsTimer.Stop() }
    if ($script:ProgressTimer) { $script:ProgressTimer.Stop() }
    if ($script:DownloadJob) {
        $job = Get-Job -Id $script:DownloadJob.Id -ErrorAction SilentlyContinue
        if ($job) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        $script:DownloadJob = $null
    }
})
$BtnRefresh.Add_Click({ Refresh-Detection })

$BtnRestart.Add_Click({
    Update-UI -Log "Reiniciando el equipo en 5 segundos..." -LogColor "#FF3333"
    Start-Sleep -Seconds 5
    Restart-Computer -Force
})

$BtnRepairWMI.Add_Click({
    Update-UI -Log "=== INICIANDO REPARACIÓN WMI (0x800706be) ===" -LogColor "#FF00FF"
    $BtnRepairWMI.IsEnabled = $false
    $ProgressBar.Value = 10
    Clear-PendingReboot
    $ProgressBar.Value = 30

    # Buscar en TODAS las rutas posibles (Program Files / Program Files (x86),
    # distintas versiones de SQL) en lugar de asumir una única ruta fija.
    $sqlRoots = @(
        "$env:ProgramFiles\Microsoft SQL Server",
        "${env:ProgramFiles(x86)}\Microsoft SQL Server"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    $mofFiles = @()
    $providerDlls = @()
    foreach ($root in $sqlRoots) {
        $mofFiles     += @(Get-ChildItem -Path $root -Filter "sqlmgmprovider*.mof" -File -Recurse -ErrorAction SilentlyContinue)
        $providerDlls += @(Get-ChildItem -Path $root -Filter "sqlmgmprovider*.dll" -File -Recurse -ErrorAction SilentlyContinue)
    }

    if ($mofFiles.Count -eq 0) {
        Update-UI -Log "No se encontró ningún MOF de sqlmgmprovider en: $($sqlRoots -join '; ')" -LogColor "#FF0000"
    } else {
        foreach ($mof in $mofFiles) {
            $mofOutput = & mofcomp.exe $mof.FullName 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Update-UI -Log "MOF recompilado: $($mof.FullName)" -LogColor "#00FF00"
            } else {
                Update-UI -Log "Error al compilar $($mof.Name): $($mofOutput.Trim())" -LogColor "#FF0000"
            }
        }
    }
    $ProgressBar.Value = 60

    if ($providerDlls.Count -eq 0) {
        Update-UI -Log "No se encontró la DLL sqlmgmprovider*.dll." -LogColor "#FF0000"
    } else {
        foreach ($dll in $providerDlls) {
            & regsvr32.exe /s $dll.FullName 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Update-UI -Log "DLL registrada: $($dll.FullName)" -LogColor "#00FF00"
            } else {
                Update-UI -Log "Error al registrar $($dll.Name) (código $LASTEXITCODE)." -LogColor "#FF0000"
            }
        }
    }
    $ProgressBar.Value = 85

    try {
        Restart-Service -Name winmgmt -Force -ErrorAction Stop
        Update-UI -Log "Servicio WMI (winmgmt) reiniciado." -LogColor "#00FF00"
    } catch {
        Update-UI -Log "No se pudo reiniciar winmgmt: $($_.Exception.Message)" -LogColor "#FFAA00"
    }

    $ProgressBar.Value = 100
    Update-UI -Log "Reparación WMI completada. Reinicia para aplicar." -LogColor "#00FF00"
    $BtnRestart.IsEnabled = $true
    $BtnRepairWMI.IsEnabled = $true
})

$BtnInventory.Add_Click({ Show-InstallerReport })
$BtnMakeFolders.Add_Click({
    $sel = $CmbSQLVersion.SelectedItem
    $key = if ($sel) { "$($sel.Tag)" } else { "ALL" }
    if ($key -eq "ALL") {
        Update-UI -Log "=== GENERANDO ESTRUCTURA PARA TODAS LAS VERSIONES ===" -LogColor "#FF00FF"
        $null = New-SQLVersionFolders -Keys @($script:SQLVersionCatalog.Key) -BaseDir $PSScriptRoot
    } else {
        $v = Get-VersionDefinition -Key $key
        if (-not $v) { return }
        Update-UI -Log "=== GENERANDO ESTRUCTURA: $($v.Name) ===" -LogColor "#FF00FF"
        $null = New-SQLVersionFolders -Keys @($key) -BaseDir $PSScriptRoot
    }
})
$BtnCatalog.Add_Click({
    $sel = $CmbSQLVersion.SelectedItem
    $key = if ($sel) { "$($sel.Tag)" } else { "ALL" }
    Show-VersionCatalog -Key $key
})
$BtnOpenRoot.Add_Click({
    Start-Process explorer.exe -ArgumentList "`"$PSScriptRoot`""
    Update-UI -Log "Carpeta raíz abierta: $PSScriptRoot" -LogColor "#00CCFF"
})
$BtnLog.Add_Click({
    if (-not (Test-Path -LiteralPath $script:LogPath)) {
        Update-UI -Log "Todavía no hay log de SQL PRIME; realiza alguna acción primero." -LogColor "#FFAA00"
        return
    }
    Start-Process notepad.exe -ArgumentList "`"$($script:LogPath)`""
    Update-UI -Log "Log de SQL PRIME abierto: $($script:LogPath)" -LogColor "#00CCFF"
})
$BtnDownload.Add_Click({ Start-InstallerDownloads })
$BtnStopDownload.Add_Click({ Stop-InstallerDownloads })

# Centro de descargas Pro: pausa/reanudacion por archivo sobre la cola persistente.
$BtnPauseFile.Add_Click({
    try {
        $name = $script:DownloadCurrentFile
        if (-not $name -and $script:DownloadQueuePath) {
            $pending = @(Get-SQLPrimeDownloadQueue -BaseDir $PSScriptRoot |
                Where-Object { $_.State -eq 'Downloading' -or $_.State -eq 'Pending' })
            if ($pending.Count -gt 0) { $name = $pending[0].Name }
        }
        if (-not $name) {
            Update-UI -Log 'No hay ningun archivo en curso para pausar.' -LogColor '#FFAA00'
            return
        }
        $entry = Set-SQLPrimeDownloadQueueState -Name $name -State 'Paused' -BaseDir $PSScriptRoot
        if ($entry) {
            Update-UI -Log "PAUSADO: $name . El fichero .part se conserva; se omitira en la siguiente pasada." -LogColor '#FFAA00'
            $script:DownloadLastSampleTime = $null
            $BtnPauseFile.IsEnabled = $false
            $BtnResumeFile.IsEnabled = $true
            try { Write-SQLPrimeStructuredLog -Level INFO -Component 'download' -OperationId $script:DownloadOperationId -Message 'Download paused' -Data @{ name=$name } } catch { }
        } else {
            Update-UI -Log "No se encontro '$name' en la cola persistente." -LogColor '#FFAA00'
        }
    } catch { Update-UI -Log "No se pudo pausar: $($_.Exception.Message)" -LogColor '#FF0000' }
})
$BtnResumeFile.Add_Click({
    try {
        $name = $script:DownloadCurrentFile
        if (-not $name -and $script:DownloadQueuePath) {
            $paused = @(Get-SQLPrimeDownloadQueue -BaseDir $PSScriptRoot | Where-Object { $_.State -eq 'Paused' })
            if ($paused.Count -gt 0) { $name = $paused[0].Name }
        }
        if (-not $name) {
            Update-UI -Log 'No hay ningun archivo pausado en la cola.' -LogColor '#FFAA00'
            return
        }
        $entry = Set-SQLPrimeDownloadQueueState -Name $name -State 'Pending' -BaseDir $PSScriptRoot
        if ($entry) {
            Update-UI -Log "REANUDADO: $name . Vuelve a la cola; se continuara desde el ultimo byte de .part." -LogColor '#00FF00'
            $BtnResumeFile.IsEnabled = $false
            $BtnPauseFile.IsEnabled = [bool]$script:DownloadJob
            try { Write-SQLPrimeStructuredLog -Level INFO -Component 'download' -OperationId $script:DownloadOperationId -Message 'Download resumed' -Data @{ name=$name } } catch { }
        } else {
            Update-UI -Log "No se encontro '$name' en la cola persistente." -LogColor '#FFAA00'
        }
    } catch { Update-UI -Log "No se pudo reanudar: $($_.Exception.Message)" -LogColor '#FF0000' }
})

$BtnWizardNext.Add_Click({
    $state = $script:WizardState
    if (-not $state) { $state = New-SQLPrimeWizardState }
    $step = [string]$state.CurrentStep
    $steps = @($state.Steps)
    $idx = [array]::IndexOf($steps, $step)
    Complete-SQLPrimeWizardStep -Step $step -Status Done
    if ($idx -eq $steps.Count - 1) {
        Update-UI -Log 'Asistente completado: 4/4 pasos registrados.' -LogColor '#00FF00'
    }
})
$BtnWizardFail.Add_Click({
    $state = $script:WizardState
    if (-not $state) { $state = New-SQLPrimeWizardState }
    Complete-SQLPrimeWizardStep -Step ([string]$state.CurrentStep) -Status Failed
})
$BtnWizardBack.Add_Click({
    $state = $script:WizardState
    if (-not $state) { $state = New-SQLPrimeWizardState }
    $script:WizardState = Get-SQLPrimeWizardPreviousState -State $state
    Update-SQLPrimeWizardUI
})
$BtnWizardReset.Add_Click({ Reset-SQLPrimeWizardUI })

$BtnService.Add_Click({ Repair-SQLService })
$BtnStopAllServices.Add_Click({ Stop-AllSQLServices })
$BtnManageServices.Add_Click({
    $inst = if ($script:DetectedInfo.Instance) { $script:DetectedInfo.Instance } else { '' }
    Show-SQLPrimeServiceManager -Instance $inst
})
$BtnReport.Add_Click({
    $inst = if ($script:DetectedInfo.Instance) { $script:DetectedInfo.Instance } else { '' }
    $null = Export-SQLPrimeReport -Instance $inst -OpenFolder -Pdf
    Complete-SQLPrimeWizardStep -Step 'Verificar' -Status Done
})
$BtnProfiles.Add_Click({
    $inst = if ($script:DetectedInfo.Instance) { $script:DetectedInfo.Instance } else { '' }
    Show-SQLPrimeProfileManager -Instance $inst
})
$BtnSchedule.Add_Click({
    $q = [System.Windows.MessageBox]::Show("¿Crear una tarea programada diaria a las 03:00 que ejecute 'SQL PRIME -StartAll' para activar TODOS los servicios SQL?", 'SQL PRIME - Programador', 'YesNo', 'Question')
    if ($q -eq 'Yes') { Register-SQLPrimeScheduledTask -ScriptPath $PSCommandPath -Action 'StartAll' -Time '03:00' }
})
$BtnSimulate.Add_Click({ Set-SQLPrimeSimulation -Enabled (-not (Test-SQLPrimeSimulation)) })
$BtnLogVerbosity.Add_Click({ $null = Set-SQLPrimeLogVerbosity })

# Filtro del log y semáforo de servicios (Bloque E).
$TxtLogFilter.Add_TextChanged({ Set-SQLPrimeLogFilter -Text $TxtLogFilter.Text })
$script:LightsTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:LightsTimer.Interval = [TimeSpan]::FromMilliseconds(3000)
$script:LightsTimer.Add_Tick({
    if ($script:ProgressWindow) { return }
    $inst = if ($script:DetectedInfo.Instance) { $script:DetectedInfo.Instance } else { '' }
    if ($inst) {
        Update-SQLPrimeLights -Instance $inst
        Update-ServiceActionButtons -Instance $inst
    }
})
$script:LightsTimer.Start()

$BtnUpdate.Add_Click({
    if (-not $script:InstallerPath -or -not (Test-Path $script:InstallerPath)) {
        Update-UI -Log "No hay un instalador válido seleccionado." -LogColor "#FF0000"
        return
    }
    if ($script:DetectedInfo.IsQFE) {
        $warn = "La instancia está en rama QFE/CU (ProductVersion $($script:DetectedInfo.ProductVersion), motor $($script:DetectedInfo.MajorVersion)).`n`n" +
                "El SP3 anterior falló con 'No se actualizó ninguna característica' (exit -2068643838): el paquete era ESN y la instalación es ENU/LCID 1033, además de la diferencia de rama.`n`n" +
                "Se va a aplicar: $(Split-Path $script:InstallerPath -Leaf)`n¿Continuar?"
        $q = [System.Windows.MessageBox]::Show($warn, "Confirmar actualización SP", "YesNo", "Warning")
        if ($q -ne "Yes") {
            Update-UI -Log "Actualización cancelada por el usuario." -LogColor "#FFAA00"
            return
        }
    }
    # Fase 0: verificación Authenticode antes de ejecutar instalador.
    if (Get-Command Test-SQLPrimeAuthenticode -ErrorAction SilentlyContinue) {
        $sig = Test-SQLPrimeAuthenticode -Path $script:InstallerPath
        $strictAuth = $false
        try { if ($script:SQLPrimeConfig -and $script:SQLPrimeConfig.security -and $script:SQLPrimeConfig.security.verifyAuthenticode) { $strictAuth = [bool]$script:SQLPrimeConfig.security.verifyAuthenticode } } catch { }
        if ($sig.Supported -and -not $sig.IsTrusted) {
            if ($strictAuth) {
                Update-UI -Log "Actualización bloqueada: firma Authenticode no confiable ($($sig.Status))." -LogColor "#FF0000"
                try { if (Get-Command Write-SQLPrimeStructuredLog -ErrorAction SilentlyContinue) { Write-SQLPrimeStructuredLog -Level ERROR -Component 'update' -OperationId $script:DownloadOperationId -Message 'Authenticode blocked' -Data @{ path=$script:InstallerPath; status=$sig.Status; trusted=$sig.IsTrusted; publisher=$sig.Publisher } } } catch { }
                return
            }
            $sigWarn = "La firma Authenticode NO es confiable para:`n$($script:InstallerPath)`n`nEstado: $($sig.Status)`nPublisher: $($sig.Publisher)`n$($sig.Message)`n`n¿Ejecutar de todos modos?"
            $sq = [System.Windows.MessageBox]::Show($sigWarn, "Advertencia de firma", "YesNo", "Warning")
            if ($sq -ne "Yes") { Update-UI -Log "Actualización cancelada: firma Authenticode no confiable." -LogColor "#FFAA00"; return }
            Update-UI -Log "Usuario confirmó ejecución pese a advertencia de firma: $($sig.Status)" -LogColor "#FFAA00"
        } elseif ($sig.Supported -and $sig.IsTrusted) {
            Update-UI -Log "Firma Authenticode verificada: $($sig.Publisher)" -LogColor "#00FF00"
        } else {
            Update-UI -Log "Authenticode no verificado en este entorno: $($sig.Message)" -LogColor "#FFAA00"
        }
        try { if (Get-Command Write-SQLPrimeStructuredLog -ErrorAction SilentlyContinue) { Write-SQLPrimeStructuredLog -Level AUDIT -Component 'update' -OperationId $script:DownloadOperationId -Message 'Authenticode check' -Data @{ path=$script:InstallerPath; status=$sig.Status; trusted=$sig.IsTrusted; publisher=$sig.Publisher; strict=$strictAuth } } } catch { }
    }

    Update-UI -Log "=== INICIANDO ACTUALIZACIÓN DE SERVICE PACK ===" -LogColor "#FF00FF"
    $BtnUpdate.IsEnabled = $false
    $ProgressBar.Value = 5
    Clear-PendingReboot | Out-Null

    # $args es una variable automática de PowerShell: nunca usarla como propia.
    $installerArgs = "/quiet /ACTION=patch /AllInstances /IAcceptSQLServerLicenseTerms"
    try {
        $script:InstallerProcess = Start-Process -FilePath $script:InstallerPath -ArgumentList $installerArgs -PassThru -NoNewWindow
        Update-UI -Log "Proceso iniciado con PID: $($script:InstallerProcess.Id). Esperando..." -LogColor "#FFFF00"

        # Evitar acumular handlers del timer si se pulsa Actualizar varias veces.
        if ($script:TickHandler) { $script:Timer.Remove_Tick($script:TickHandler) }
        $script:Timer.Interval = [TimeSpan]::FromMilliseconds(500)

        $script:TickHandler = {
            try {
                if ($script:InstallerProcess -and $script:InstallerProcess.HasExited) {
                    $script:Timer.Stop()
                    $exitCode = $script:InstallerProcess.ExitCode
                    $ProgressBar.Value = 100

                    if ($exitCode -eq 0 -or $exitCode -eq 3010 -or $exitCode -eq 1641) {
                        Update-UI -Log "¡Actualización completada! Código: $exitCode" -LogColor "#00FF00"
                        $BtnRestart.IsEnabled = $true
                        Update-UI -Log "Reinicia el equipo y luego pulsa REFRESCAR ESTADO." -LogColor "#FFFF00"
                        Complete-SQLPrimeWizardStep -Step 'Aplicar' -Status Done
                    } else {
                        Update-UI -Log "Error en el instalador. Código: $exitCode" -LogColor "#FF0000"
                        Complete-SQLPrimeWizardStep -Step 'Aplicar' -Status Failed
                    }
                    $BtnUpdate.IsEnabled = $true
                } elseif ($ProgressBar.Value -lt 95) {
                    $ProgressBar.Value += 0.3
                }
            } catch {
                $script:Timer.Stop()
                Update-UI -Log "Error al supervisar el instalador: $($_.Exception.Message)" -LogColor "#FF0000"
                $BtnUpdate.IsEnabled = $true
            }
        }
        $script:Timer.Add_Tick($script:TickHandler)
        $script:Timer.Start()
    } catch {
        Update-UI -Log "Error al iniciar: $($_.Exception.Message)" -LogColor "#FF0000"
        $BtnUpdate.IsEnabled = $true
    }
})

# ==============================================================================
# 8. ARRANQUE
# ==============================================================================
Update-UI -Log "Script iniciado con privilegios elevados." -LogColor "#00CCFF"
Update-UI -Log "Pulsa INVENTARIO / DESCARGAS para ver todos los ficheros y las rutas oficiales." -LogColor "#8888AA"
Refresh-Detection
try { Initialize-SQLPrimeLights -Instance $script:DetectedInfo.Instance } catch { }
$BtnSimulate.Content = if (Test-SQLPrimeSimulation) { '🧪 SIMULACIÓN: ON' } else { '🧪 SIMULACIÓN: OFF' }
$BtnLogVerbosity.Content = "📝 LOG: $((Get-SQLPrimeLogVerbosity).ToUpper())"
Write-SQLPrimeLog -Level INFO -Message "SQL PRIME listo | elevado=$(Test-SQLPrimeAdmin) | tema=$script:CurrentTheme | log=$(Get-SQLPrimeLogVerbosity) | modo rápido=$([bool]($script:Options.FastMode))"

if ($script:CliAction) {
    Invoke-SQLPrimeCli -Action $script:CliAction -Instance $script:DetectedInfo.Instance
    $window.Close()
} else {
    $window.ShowDialog() | Out-Null
}