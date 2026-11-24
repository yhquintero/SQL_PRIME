<#
.SYNOPSIS
    Modulo de mejoras avanzadas de SQL PRIME (dot-source desde el script principal).
.DESCRIPTION
    Bloque A - Seguridad: confirmacion por escritura, punto de restauracion, simulacion.
    Bloque B - Gestion fina: panel de servicios, diagnóstico, cancelacion del modal.
    Bloque C - Informes: snapshot antes/despues, exportacion CSV y HTML, historial.
    Bloque D - Robustez: timeouts/reintentos configurables y diagnostico automatico.
    Bloque E - UX: semaforo por servicio y filtro del log.
    Bloque F - Automatizacion: perfiles, modo CLI y Programador de tareas.
    Bloque G - Velocidad:arranque/parada en dos fases (emitir y esperar), sondeo
               adaptativo y esperas condicionales en la reparacion.
    Bloque H - Trazabilidad: log con niveles, comandos ejecutados, tiempos por
               servicio, comparativa ANTES/DESPUES y duracion total.
#>

$script:OptionsPath  = Join-Path $PSScriptRoot "sql_prime_options.json"
$script:ProfilesPath = Join-Path $PSScriptRoot "sql_prime_profiles.json"
$script:Snapshots    = @()
$script:ServiceLightsMap = @{}

# ------------------------------------------------------------------------------
# Configuracion de opciones avanzadas
# ------------------------------------------------------------------------------
function Initialize-SQLPrimeOptions {
    $o = @{}
    if (Test-Path -LiteralPath $script:OptionsPath) {
        try {
            $c = Get-Content -LiteralPath $script:OptionsPath -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($c) { foreach ($p in $c.PSObject.Properties) { $o[$p.Name] = $p.Value } }
        } catch { }
    }
    $defaults = @{
        SimulationMode      = $false
        StartTimeoutSec     = 30
        StopTimeoutSec      = 20
        RetryCount          = 2
        ReportBeforeAfter   = $true
        RestorePointOnStop  = $true
        LightsIntervalMs    = 3000
        LogVerbosity        = 'Normal'   # Normal | Detallado | Diagnóstico
        FastMode            = $true      # Arrancar/parar en dos fases sin espera por servicio.
        PollIntervalMs      = 200        # Sondeo adaptativo de estados.
    }
    foreach ($k in $defaults.Keys) { if (-not $o.ContainsKey($k)) { $o[$k] = $defaults[$k] } }
    $script:Options = $o
}

function Save-SQLPrimeOptions {
    try { $script:Options | ConvertTo-Json | Out-File -FilePath $script:OptionsPath -Encoding utf8 -Force } catch { }
}

function Set-SQLPrimeOption {
    param([string]$Name, $Value)
    if (-not $script:Options) { Initialize-SQLPrimeOptions }
    $script:Options[$Name] = $Value
    Save-SQLPrimeOptions
}

function Test-SQLPrimeAdmin {
    try {
        $p = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Test-SQLPrimeSimulation {
    if (-not $script:Options) { Initialize-SQLPrimeOptions }
    return [bool]$script:Options.SimulationMode
}

function Set-SQLPrimeSimulation {
    param([bool]$Enabled)
    Set-SQLPrimeOption -Name 'SimulationMode' -Value $Enabled
    $btn = $window.FindName('BtnSimulate')
    if ($null -ne $btn) {
        $btn.Content = if ($Enabled) { '🧪 SIMULACIÓN: ON' } else { '🧪 SIMULACIÓN: OFF' }
        $btn.Background = if ($Enabled) { [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF00FF') } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString('#4455AA') }
    }
    if ($Enabled) {
        Update-UI -Log 'MODO SIMULACIÓN ACTIVADO: no se detendrá ni iniciará ningún servicio; se mostrará lo que se haría.' -LogColor '#FF00FF'
    } else {
        Update-UI -Log 'Modo simulación desactivado: las operaciones se ejecutarán normalmente.' -LogColor '#00FF00'
    }
}

# ------------------------------------------------------------------------------
# Bloque H: nivel de detalle del log
# ------------------------------------------------------------------------------
function Get-SQLPrimeLogVerbosity {
    if (-not $script:Options) { Initialize-SQLPrimeOptions }
    $v = [string]$script:Options.LogVerbosity
    if ($v -notin @('Normal','Detallado','Diagnóstico')) { $v = 'Normal' }
    return $v
}

function Set-SQLPrimeLogVerbosity {
    $orden = @('Normal','Detallado','Diagnóstico')
    $idx = [Array]::IndexOf($orden, (Get-SQLPrimeLogVerbosity))
    if ($idx -lt 0) { $idx = 0 }
    $next = $orden[($idx + 1) % $orden.Count]
    Set-SQLPrimeOption -Name 'LogVerbosity' -Value $next
    if ($null -ne $window) {
        $btn = $window.FindName('BtnLogVerbosity')
        if ($null -ne $btn) { $btn.Content = "📝 LOG: $($next.ToUpper())" }
    }
    $detail = switch ($next) {
        'Normal'      { 'solo resultados y avisos' }
        'Detallado'   { 'se incluyen TODOS los comandos y cambios de estado' }
        'Diagnóstico' { 'se incluyen ademas tiempos internos y sondeos' }
    }
    Update-UI -Log "Nivel de log: $next ($detail)." -LogColor '#00CCFF'
    return $next
}

# ------------------------------------------------------------------------------
# Bloque A: confirmacion por escritura y punto de restauracion
# ------------------------------------------------------------------------------
function Show-SQLPrimeTypedConfirmation {
    param([string]$Word, [string]$Title, [string]$Message)

    # El texto se inyecta en XAML: se escapan &, <, > y comillas.
    $xTitle   = [System.Security.SecurityElement]::Escape($Title)
    $xMessage = [System.Security.SecurityElement]::Escape(($Message -replace "`r`n", "`n"))
    $xWord    = [System.Security.SecurityElement]::Escape($Word)

    [xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$xTitle" Width="520" Height="290" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
        Foreground="#FFFFFF" FontFamily="Segoe UI, Segoe UI Emoji">
    <Border CornerRadius="10" Background="#14141F" BorderBrush="#FF3333" BorderThickness="2">
        <Border.Effect><DropShadowEffect Color="#FF3333" BlurRadius="16" ShadowDepth="0" Opacity="0.65"/></Border.Effect>
        <Grid Margin="16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Text="$xTitle" Foreground="#FF6666" FontWeight="Bold" FontSize="15"/>
            <TextBlock Grid.Row="1" Text="$xMessage" Foreground="#DDDDDD" FontSize="12" TextWrapping="Wrap" Margin="0,12,0,8"/>
            <StackPanel Grid.Row="2" Orientation="Horizontal">
                <TextBlock Text="Escribe  " Foreground="#AAAAAA" VerticalAlignment="Center"/>
                <TextBlock Text="$xWord" Foreground="#FF6666" FontWeight="Bold" VerticalAlignment="Center"/>
                <TextBox x:Name="ConfirmText" Width="180" Height="30" Margin="10,0,0,0" VerticalContentAlignment="Center"
                         Background="#08080C" Foreground="#FFFFFF" BorderBrush="#555566"/>
            </StackPanel>
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,14,0,0">
                <Button x:Name="ConfirmOk" Content="CONFIRMAR" Width="120" Height="34" Margin="0,0,8,0"
                        Background="#C42B1C" Foreground="#FFFFFF" FontWeight="Bold" Cursor="Hand"/>
                <Button x:Name="ConfirmCancel" Content="CANCELAR" Width="120" Height="34"
                        Background="#333344" Foreground="#FFFFFF" FontWeight="Bold" Cursor="Hand"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@

    try {
        $reader = New-Object System.Xml.XmlNodeReader $x
        $dlg = [Windows.Markup.XamlReader]::Load($reader)
        if ($window) { $dlg.Owner = $window }
        $tb = $dlg.FindName('ConfirmText')
        $dlg.FindName('ConfirmOk').Add_Click({
            if ($tb.Text.Trim() -ceq $Word) { $dlg.DialogResult = $true } else {
                [System.Windows.MessageBox]::Show("Debes escribir exactamente: $Word", 'Confirmación', 'OK', 'Warning')
            }
        })
        $dlg.FindName('ConfirmCancel').Add_Click({ $dlg.DialogResult = $false })
        $tb.Add_KeyDown({
            if ($_.Key -eq [System.Windows.Input.Key]::Enter) { $dlg.FindName('ConfirmOk').RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)) }
        })
        $tb.Focus()
        $r = $dlg.ShowDialog()
        return [bool]$r
    } catch {
        Update-UI -Log "No se pudo mostrar la confirmación: $($_.Exception.Message)" -LogColor '#FF0000'
        return $false
    }
}

function New-SQLPrimeRestorePoint {
    param([string]$Reason = 'antes de desactivar servicios SQL')
    if (-not (Test-SQLPrimeAdmin)) {
        Update-UI -Log 'No se creó el punto de restauración: se necesita administrador.' -LogColor '#FFAA00'
        return $false
    }
    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
        Update-UI -Log 'Checkpoint-Computer no está disponible en este equipo; se continúa sin punto de restauración.' -LogColor '#FFAA00'
        return $false
    }
    try {
        Update-UI -Log "Creando punto de restauración ($Reason)..." -LogColor '#00CCFF'
        Checkpoint-Computer -Description "SQL PRIME - $Reason" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Update-UI -Log '✓ Punto de restauración creado correctamente.' -LogColor '#00FF00'
        return $true
    } catch {
        Update-UI -Log "No se pudo crear el punto de restauración (se continúa): $($_.Exception.Message)" -LogColor '#FFAA00'
        return $false
    }
}

# ------------------------------------------------------------------------------
# Bloque C: snapshots, informes CSV/HTML e historial
# ------------------------------------------------------------------------------
function Save-SQLPrimeSnapshot {
    param([ValidateSet('ANTES','DESPUES')][string]$Phase, [string]$Instance)
    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    foreach ($name in @(Get-SQLServiceCandidates -Instance $Instance)) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        $script:Snapshots += [pscustomobject]@{
            Phase     = $Phase
            Time      = $time
            Instance  = $Instance
            Service   = $name
            Installed = [bool]$svc
            Status    = if ($svc) { [string]$svc.Status } else { 'NO INSTALADO' }
            StartType = if ($svc) { [string]$svc.StartType } else { '-' }
        }
    }
    Update-UI -Log "[REPORTE] Snapshot $Phase guardado para $Instance ($((@(Get-SQLServiceCandidates -Instance $Instance)).Count) servicios)." -LogColor '#00CCFF'
}

function Export-SQLPrimeReport {
    param([string]$Instance, [switch]$OpenFolder)
    if (-not $script:Snapshots -or $script:Snapshots.Count -eq 0) {
        Update-UI -Log 'No hay datos de servicios para exportar; ejecuta primero Reparar o Desactivar.' -LogColor '#FFAA00'
        return
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $csv = Join-Path $PSScriptRoot "SQL_PRIME_Servicios_$stamp.csv"
    $html = Join-Path $PSScriptRoot "SQL_PRIME_Servicios_$stamp.html"
    try {
        $script:Snapshots | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8 -Force
        $enc = { param($v) [System.Net.WebUtility]::HtmlEncode([string]$v) }
        $rows = foreach ($s in $script:Snapshots) {
            $color = if ($s.Status -eq 'Running') { '#00AA00' } elseif ($s.Status -eq 'Stopped') { '#AA6600' } else { '#888888' }
            "<tr><td>$(& $enc $s.Phase)</td><td>$(& $enc $s.Time)</td><td>$(& $enc $s.Service)</td><td style='color:$color;font-weight:bold'>$(& $enc $s.Status)</td><td>$(& $enc $s.StartType)</td><td>$(& $enc $s.Instance)</td></tr>"
        }
        $hInstance = & $enc $Instance
        $hMachine  = & $enc $env:COMPUTERNAME
        $elapsed = if ($script:ProgressStopwatch) { $script:ProgressStopwatch.Elapsed.ToString('hh\:mm\:ss') } else { 'no disponible' }
        $doc = @"
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>SQL PRIME - Informe de Servicios</title>
<style>body{background:#0D0D14;color:#DDD;font-family:Segoe UI;margin:24px}h1{color:#00FFFF}h2{color:#FF00FF}
table{border-collapse:collapse;width:100%;background:#14141F}th,td{border:1px solid #333355;padding:6px 10px;text-align:left;font-size:13px}th{background:#222233;color:#00FFFF}</style>
</head><body><h1>SQL PRIME - Informe de Servicios</h1><h2>Instancia: $hInstance</h2>
<p>Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Equipo: $hMachine | Tiempo de la última operación: $elapsed</p>
<table><tr><th>Fase</th><th>Hora</th><th>Servicio</th><th>Estado</th><th>Inicio</th><th>Instancia</th></tr>
$($rows -join "`n")</table></body></html>
"@
        [System.IO.File]::WriteAllText($html, $doc, (New-Object System.Text.UTF8Encoding($false)))
        Update-UI -Log "[REPORTE] CSV: $csv" -LogColor '#00FF00'
        Update-UI -Log "[REPORTE] HTML: $html" -LogColor '#00FF00'
        if ($OpenFolder) { Start-Process explorer.exe -ArgumentList "/select,`"$csv`"" }
        return @{ Csv = $csv; Html = $html }
    } catch {
        Update-UI -Log "No se pudo exportar el informe: $($_.Exception.Message)" -LogColor '#FF0000'
        return $null
    }
}

# ------------------------------------------------------------------------------
# Bloque B/D: diagnóstico de un servicio
# ------------------------------------------------------------------------------
function Get-SQLPrimeServiceDiagnostic {
    param([string]$Name)
    $lines = @("=== DIAGNÓSTICO: $Name ===")
    try {
        $qc = & sc.exe qc $Name 2>&1
        $lines += ($qc | Select-Object -First 12)
    } catch { $lines += "sc.exe qc no disponible: $($_.Exception.Message)" }
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($svc) {
            $lines += "Estado: $($svc.Status) | Inicio: $($svc.StartType) | Nombre: $($svc.DisplayName)"
            $deps = @($svc.RequiredServices | ForEach-Object { $_.Name })
            $lines += "Depende de: $(if ($deps.Count) { $deps -join ', ' } else { 'ninguna' })"
        }
    } catch { }
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName='System'; StartTime=(Get-Date).AddHours(-2) } -MaxEvents 200 -ErrorAction SilentlyContinue |
                  Where-Object { $_.Message -like "*$Name*" } | Select-Object -First 5
        foreach ($e in $events) { $lines += "[$($e.TimeCreated.ToString('HH:mm:ss'))] Id=$($e.Id) $($e.ProviderName): $(($e.Message -split "`n")[0])" }
    } catch { }
    return ($lines -join "`r`n")
}

# ------------------------------------------------------------------------------
# Bloque B: gestion fina de servicios (checkboxes)
# ------------------------------------------------------------------------------
function Show-SQLPrimeServiceManager {
    param([string]$Instance)

    if (-not (Test-SQLPrimeAdmin)) {
        Update-UI -Log 'Se necesita administrador para gestionar servicios.' -LogColor '#FF0000'
        return
    }

    [xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SQL PRIME - Gestión de servicios" Width="640" Height="470"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize" Foreground="#FFFFFF"
        FontFamily="Segoe UI, Segoe UI Emoji">
    <Border CornerRadius="10" Background="#14141F" BorderBrush="#00FFFF" BorderThickness="2">
        <Border.Effect><DropShadowEffect Color="#00FFFF" BlurRadius="16" ShadowDepth="0" Opacity="0.6"/></Border.Effect>
        <Grid Margin="16">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Text="GESTIÓN FINA DE SERVICIOS SQL" Foreground="#00FFFF" FontWeight="Bold" FontSize="15" x:Name="MgrTitle"/>
            <Border Grid.Row="1" Margin="0,10,0,8" Background="#08080C" CornerRadius="6" BorderBrush="#333355" BorderThickness="1">
                <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="MgrList"/></ScrollViewer>
            </Border>
            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,4,0,4">
                <Button x:Name="MgrStart" Content="▶ INICIAR MARCADOS" Width="170" Height="34" Margin="4" Background="#00AA88" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
                <Button x:Name="MgrStop" Content="⛔ DETENER MARCADOS" Width="170" Height="34" Margin="4" Background="#8B1A1A" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
                <Button x:Name="MgrDetail" Content="🔍 VER DIAGNÓSTICO" Width="170" Height="34" Margin="4" Background="#4455AA" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
            </StackPanel>
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="MgrClose" Content="CERRAR" Width="130" Height="34" Background="#333344" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
    try {
        $reader = New-Object System.Xml.XmlNodeReader $x
        $dlg = [Windows.Markup.XamlReader]::Load($reader)
        if ($window) { $dlg.Owner = $window }
        $list = $dlg.FindName('MgrList')
        $dlg.FindName('MgrTitle').Text = "GESTIÓN FINA DE SERVICIOS SQL - $Instance"
        foreach ($name in @(Get-SQLServiceCandidates -Instance $Instance)) {
            $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
            if (-not $svc) { continue }
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $name
            $cb.Content = "$name  [$($svc.Status) / $($svc.StartType)]"
            $cb.IsChecked = ($svc.Status -eq 'Running')
            $cb.Foreground = if ($svc.Status -eq 'Running') { [System.Windows.Media.BrushConverter]::new().ConvertFromString('#00FF88') } else { [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FFAA00') }
            $cb.Margin = [System.Windows.Thickness]::new(0, 3, 0, 3)
            $list.Children.Add($cb) | Out-Null
        }

        function Get-MarkedServices {
            $r = @()
            foreach ($cb in $list.Children) { if ($cb -is [System.Windows.Controls.CheckBox] -and $cb.IsChecked) { $r += [string]$cb.Tag } }
            return $r
        }

        $dlg.FindName('MgrStart').Add_Click({
            $marked = @(Get-MarkedServices)
            if ($marked.Count -eq 0) { [System.Windows.MessageBox]::Show('Marca al menos un servicio.', 'SQL PRIME', 'OK', 'Information'); return }
            Show-ServiceProgressModal -Title 'INICIANDO SERVICIOS' -Subtitle "Instancia: $Instance" -Total $marked.Count
            try {
                $i = 0
                foreach ($n in $marked) {
                    if ($script:ProgressCancelled) { break }
                    $i++
                    Update-ServiceProgressModal -Service $n -Status 'iniciando...' -Done ($i - 1) -Total $marked.Count -Color '#FFFF00'
                    if (Test-SQLPrimeSimulation) { Update-UI -Log "[SIMULACIÓN] Se iniciaría $n" -LogColor '#FF00FF'; Update-ServiceProgressModal -Service $n -Status 'simulado' -Done $i -Total $marked.Count -Color '#FF00FF'; continue }
                    try {
                        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
                        if ($s -and $s.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) { Set-Service -Name $n -StartupType Automatic }
                        Start-Service -Name $n -ErrorAction Stop
                        Update-UI -Log "✓ $n iniciado desde gestión fina." -LogColor '#00FF00'
                        Update-ServiceProgressModal -Service $n -Status 'en ejecución' -Done $i -Total $marked.Count -Color '#00FF00'
                    } catch {
                        Update-UI -Log "No se pudo iniciar $n : $($_.Exception.Message)" -LogColor '#FF0000'
                        Update-ServiceProgressModal -Service $n -Status 'incidencia' -Done $i -Total $marked.Count -Color '#FF0000'
                        Update-UI -Log (Get-SQLPrimeServiceDiagnostic -Name $n) -LogColor '#FFAA00'
                    }
                }
            } finally { Close-ServiceProgressModal }
            Update-SQLPrimeLights -Instance $Instance
            if (Get-Command Update-ServiceActionButtons -ErrorAction SilentlyContinue) { Update-ServiceActionButtons -Instance $Instance }
        })

        $dlg.FindName('MgrStop').Add_Click({
            $marked = @(Get-MarkedServices)
            if ($marked.Count -eq 0) { [System.Windows.MessageBox]::Show('Marca al menos un servicio.', 'SQL PRIME', 'OK', 'Information'); return }
            Show-ServiceProgressModal -Title 'DETENIENDO SERVICIOS' -Subtitle "Instancia: $Instance" -Total $marked.Count
            try {
                $i = 0
                foreach ($n in $marked) {
                    if ($script:ProgressCancelled) { break }
                    $i++
                    Update-ServiceProgressModal -Service $n -Status 'deteniendo...' -Done ($i - 1) -Total $marked.Count -Color '#FFFF00'
                    if (Test-SQLPrimeSimulation) { Update-UI -Log "[SIMULACIÓN] Se detendría $n" -LogColor '#FF00FF'; Update-ServiceProgressModal -Service $n -Status 'simulado' -Done $i -Total $marked.Count -Color '#FF00FF'; continue }
                    try {
                        Stop-Service -Name $n -Force -ErrorAction Stop
                        Update-UI -Log "⛔ $n detenido desde gestión fina." -LogColor '#FFAA00'
                        Update-ServiceProgressModal -Service $n -Status 'detenido' -Done $i -Total $marked.Count -Color '#FFAA00'
                    } catch {
                        Update-UI -Log "No se pudo detener $n : $($_.Exception.Message)" -LogColor '#FF0000'
                        Update-ServiceProgressModal -Service $n -Status 'incidencia' -Done $i -Total $marked.Count -Color '#FF0000'
                        Update-UI -Log (Get-SQLPrimeServiceDiagnostic -Name $n) -LogColor '#FFAA00'
                    }
                }
            } finally { Close-ServiceProgressModal }
            Update-SQLPrimeLights -Instance $Instance
            if (Get-Command Update-ServiceActionButtons -ErrorAction SilentlyContinue) { Update-ServiceActionButtons -Instance $Instance }
        })

        $dlg.FindName('MgrDetail').Add_Click({
            $marked = @(Get-MarkedServices)
            $n = if ($marked.Count) { $marked[0] } else { '' }
            if (-not $n) { [System.Windows.MessageBox]::Show('Marca al menos un servicio.', 'SQL PRIME', 'OK', 'Information'); return }
            $diag = Get-SQLPrimeServiceDiagnostic -Name $n
            [System.Windows.MessageBox]::Show($diag, "Diagnóstico - $n", 'OK', 'Information')
            Update-UI -Log "[DIAGNÓSTICO] $n`r`n$diag" -LogColor '#00CCFF'
        })

        $dlg.FindName('MgrClose').Add_Click({ $dlg.DialogResult = $true })
        $dlg.ShowDialog() | Out-Null
    } catch {
        Update-UI -Log "No se pudo abrir la gestión de servicios: $($_.Exception.Message)" -LogColor '#FF0000'
    }
}

# ------------------------------------------------------------------------------
# Bloque E: semáforo de servicios
# ------------------------------------------------------------------------------
function Initialize-SQLPrimeLights {
    param([string]$Instance)
    $panel = $window.FindName('ServiceLights')
    if ($null -eq $panel) { return }
    $panel.Children.Clear()
    $script:ServiceLightsMap = @{}
    foreach ($name in @(Get-SQLServiceCandidates -Instance $Instance)) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) { continue }
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = '⚫ ' + $name
        $tb.FontSize = 10
        $tb.Margin = [System.Windows.Thickness]::new(2, 0, 8, 0)
        $panel.Children.Add($tb) | Out-Null
        $script:ServiceLightsMap[$name] = $tb
    }
    Update-SQLPrimeLights -Instance $Instance
}

function Update-SQLPrimeLights {
    param([string]$Instance)
    if (-not $script:ServiceLightsMap -or $script:ServiceLightsMap.Count -eq 0) { return }
    foreach ($name in @($script:ServiceLightsMap.Keys)) {
        $tb = $script:ServiceLightsMap[$name]
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) { $tb.Text = "⚫ $name"; $tb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#666666'); continue }
        if ($svc.Status -eq 'Running') {
            $tb.Text = "🟢 $name"; $tb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#00FF88')
        } elseif ($svc.Status -eq 'Stopped' -and $svc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) {
            $tb.Text = "🔴 $name"; $tb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF5555')
        } else {
            $tb.Text = "🟡 $name"; $tb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FFCC00')
        }
    }
}

# ------------------------------------------------------------------------------
# Bloque E: filtro del log (se apoya en $script:LogDisplayLines del principal)
# ------------------------------------------------------------------------------
function Set-SQLPrimeLogFilter {
    param([string]$Text)
    if (-not $TxtLog) { return }
    $filter = if ($Text) { $Text.Trim() } else { '' }
    $TxtLog.Document.Blocks.Clear()
    foreach ($entry in @($script:LogDisplayLines)) {
        if ($filter -and $entry.Text -notlike "*$filter*") { continue }
        $p = New-Object System.Windows.Documents.Paragraph
        $r = New-Object System.Windows.Documents.Run("$($entry.Time) $($entry.Text)")
        try { $r.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($entry.Color) } catch { }
        $p.Inlines.Add($r)
        $TxtLog.Document.Blocks.Add($p)
    }
    if ($filter) { Update-UI -Log "Filtro aplicado: '$filter' ($($TxtLog.Document.Blocks.Count) líneas)." -LogColor '#00CCFF' }
    $ScrollLog.ScrollToEnd()
}

# ------------------------------------------------------------------------------
# Bloque F: perfiles de servicios
# ------------------------------------------------------------------------------
function Get-SQLPrimeProfiles {
    if (-not (Test-Path -LiteralPath $script:ProfilesPath)) { return @{} }
    try {
        $c = Get-Content -LiteralPath $script:ProfilesPath -Raw | ConvertFrom-Json
        $h = @{}
        if ($c) { foreach ($p in $c.PSObject.Properties) { $h[$p.Name] = $p.Value } }
        return $h
    } catch { return @{} }
}

function Save-SQLPrimeProfiles {
    param([hashtable]$Profiles)
    try { $Profiles | ConvertTo-Json -Depth 5 | Out-File -FilePath $script:ProfilesPath -Encoding utf8 -Force } catch { }
}

function Show-SQLPrimeProfileManager {
    param([string]$Instance)
    if (-not $Instance) { Update-UI -Log 'No hay instancia detectada.' -LogColor '#FF0000'; return }

    [xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SQL PRIME - Perfiles" Width="520" Height="420" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
        Foreground="#FFFFFF" FontFamily="Segoe UI, Segoe UI Emoji">
    <Border CornerRadius="10" Background="#14141F" BorderBrush="#8866CC" BorderThickness="2">
        <Grid Margin="16">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <TextBlock Text="PERFILES DE SERVICIOS" Foreground="#AA88FF" FontWeight="Bold" FontSize="15"/>
            <ListBox x:Name="ProfList" Grid.Row="1" Margin="0,12,0,8" Background="#08080C" Foreground="#DDDDDD" BorderBrush="#333355"/>
            <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,4,0,4">
                <TextBox x:Name="ProfName" Width="180" Height="30" VerticalContentAlignment="Center" Background="#08080C" Foreground="#FFF" BorderBrush="#555566" ToolTip="Nombre del perfil"/>
                <Button x:Name="ProfSave" Content="💾 GUARDAR ACTUAL" Width="150" Height="30" Margin="8,0,0,0" Background="#8866CC" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
            </StackPanel>
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="ProfApplyActive" Content="▶ APLICAR TODO ACTIVO" Width="150" Height="32" Margin="4" Background="#00AA88" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
                <Button x:Name="ProfApplyStopped" Content="⛔ APLICAR TODO DETENIDO" Width="170" Height="32" Margin="4" Background="#8B1A1A" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
                <Button x:Name="ProfClose" Content="CERRAR" Width="100" Height="32" Margin="4" Background="#333344" Foreground="#FFF" FontWeight="Bold" Cursor="Hand"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
    try {
        $reader = New-Object System.Xml.XmlNodeReader $x
        $dlg = [Windows.Markup.XamlReader]::Load($reader)
        if ($window) { $dlg.Owner = $window }
        $lb = $dlg.FindName('ProfList')
        $profiles = Get-SQLPrimeProfiles
        foreach ($k in @($profiles.Keys)) { $lb.Items.Add("$k") | Out-Null }
        if ($lb.Items.Count -eq 0) { $lb.Items.Add('(sin perfiles guardados)') | Out-Null }

        $dlg.FindName('ProfSave').Add_Click({
            $n = $dlg.FindName('ProfName').Text.Trim()
            if (-not $n) { [System.Windows.MessageBox]::Show('Escribe un nombre de perfil.', 'SQL PRIME', 'OK', 'Warning'); return }
            $profiles = Get-SQLPrimeProfiles
            $state = @{}
            foreach ($name in @(Get-SQLServiceCandidates -Instance $Instance)) {
                $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
                if ($svc) { $state[$name] = [string]$svc.Status }
            }
            $profiles[$n] = $state
            Save-SQLPrimeProfiles -Profiles $profiles
            Update-UI -Log "Perfil guardado: $n ($($state.Count) servicios)." -LogColor '#00FF00'
            $dlg.DialogResult = $true
        })

        $applyProfile = {
            param([string]$Desired)
            $sel = [string]$lb.SelectedItem
            if (-not $sel -or $sel -like '(sin perfiles*') { [System.Windows.MessageBox]::Show('Selecciona un perfil.', 'SQL PRIME', 'OK', 'Warning'); return }
            $profiles = Get-SQLPrimeProfiles
            if (-not $profiles.ContainsKey($sel)) { return }
            if (-not (Test-SQLPrimeAdmin)) { Update-UI -Log 'Se necesita administrador para aplicar perfiles.' -LogColor '#FF0000'; return }
            foreach ($n in @($profiles[$sel].PSObject.Properties)) {
                $svcName = $n.Name
                $target = if ($Desired -eq 'Running') { 'Running' } else { 'Stopped' }
                if (Test-SQLPrimeSimulation) { Update-UI -Log "[SIMULACIÓN] $svcName -> $target" -LogColor '#FF00FF'; continue }
                try {
                    if ($target -eq 'Running') {
                        $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($s -and $s.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) { Set-Service -Name $svcName -StartupType Automatic }
                        Start-Service -Name $svcName -ErrorAction SilentlyContinue
                    } else { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
                } catch { }
            }
            Update-UI -Log "Perfil aplicado: $sel (objetivo $Desired)." -LogColor '#00FF00'
            Update-SQLPrimeLights -Instance $Instance
            if (Get-Command Update-ServiceActionButtons -ErrorAction SilentlyContinue) { Update-ServiceActionButtons -Instance $Instance }
        }

        $dlg.FindName('ProfApplyActive').Add_Click({ & $applyProfile 'Running' })
        $dlg.FindName('ProfApplyStopped').Add_Click({ & $applyProfile 'Stopped' })
        $dlg.FindName('ProfClose').Add_Click({ $dlg.DialogResult = $true })
        $dlg.ShowDialog() | Out-Null
    } catch {
        Update-UI -Log "No se pudo abrir la gestión de perfiles: $($_.Exception.Message)" -LogColor '#FF0000'
    }
}

# ------------------------------------------------------------------------------
# Bloque F: Programador de tareas y modo CLI
# ------------------------------------------------------------------------------
function Register-SQLPrimeScheduledTask {
    param([string]$ScriptPath, [string]$Action = 'StartAll', [string]$Time = '03:00')
    if (-not (Test-SQLPrimeAdmin)) { Update-UI -Log 'Se necesita administrador para crear la tarea programada.' -LogColor '#FF0000'; return }
    $name = "SQL PRIME - $Action servicios SQL"
    try {
        $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -$Action"
        $a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $t = New-ScheduledTaskTrigger -Daily -At $Time
        Register-ScheduledTask -TaskName $name -Action $a -Trigger $t -Description 'Creada por SQL PRIME' -RunLevel Highest -Force -ErrorAction Stop | Out-Null
        Update-UI -Log "✓ Tarea programada creada: '$name' diaria a las $Time." -LogColor '#00FF00'
    } catch {
        Update-UI -Log "No se pudo crear la tarea programada: $($_.Exception.Message)" -LogColor '#FF0000'
    }
}

function Invoke-SQLPrimeCli {
    param([string]$Action, [string]$Instance = '')
    Initialize-SQLPrimeOptions
    if (-not $Instance) {
        try { $Instance = (Get-SQLServerInfo).Instance } catch { }
    }
    Write-Host "SQL PRIME - modo CLI: $Action (instancia: $Instance)" -ForegroundColor Cyan
    switch ($Action) {
        'StartAll' {
            Start-AllSQLServices -Instance $Instance -InstanceId '' | Out-Null
            Test-AllSQLServices -Instance $Instance -ExpectedState 'Running' | Out-Null
        }
        'StopAll' {
            if (-not (Test-SQLPrimeAdmin)) { Write-Host 'Se necesita administrador.' -ForegroundColor Red; return }
            $c = @(Get-SQLServiceCandidates -Instance $Instance); [Array]::Reverse($c)
            foreach ($n in $c) {
                $s = Get-Service -Name $n -ErrorAction SilentlyContinue
                if ($s -and $s.Status -ne 'Stopped') { Stop-Service -Name $n -Force -ErrorAction SilentlyContinue }
                if ($s) { Set-Service -Name $n -StartupType Disabled -ErrorAction SilentlyContinue }
                Write-Host "  ⛔ $n desactivado"
            }
            Test-AllSQLServices -Instance $Instance -ExpectedState 'Stopped' | Out-Null
        }
        'Verify' { Test-AllSQLServices -Instance $Instance -ExpectedState 'Running' | Out-Null }
        'Report' { Export-SQLPrimeReport -Instance $Instance | Out-Null }
    }
    Write-Host 'SQL PRIME - CLI finalizado.' -ForegroundColor Green
}
