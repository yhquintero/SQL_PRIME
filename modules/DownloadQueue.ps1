# SQL PRIME - Persistent download queue (Phase 1 / download center Pro)
# Pure functions: no UI, no network. Safe to call from the WPF timer and the download job.

function Get-SQLPrimeDownloadQueuePath {
    param([string]$BaseDir = (Split-Path $PSScriptRoot -Parent))
    $dir = Join-Path $BaseDir 'logs'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return (Join-Path $dir 'download_queue.json')
}

function Get-SQLPrimeDownloadQueue {
    param([string]$BaseDir = (Split-Path $PSScriptRoot -Parent))
    $path = Get-SQLPrimeDownloadQueuePath -BaseDir $BaseDir
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        $raw = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        return @($raw)
    } catch { return @() }
}

function Save-SQLPrimeDownloadQueue {
    param(
        [Parameter(Mandatory = $true)][object[]]$Entries,
        [string]$BaseDir = (Split-Path $PSScriptRoot -Parent)
    )
    $path = Get-SQLPrimeDownloadQueuePath -BaseDir $BaseDir
    $json = $Entries | ConvertTo-Json -Depth 6
    $tmp = "$path.tmp"
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    $moved = $false
    for ($i = 0; $i -lt 5 -and -not $moved; $i++) {
        try { Move-Item -LiteralPath $tmp -Destination $path -Force -ErrorAction Stop; $moved = $true }
        catch { Start-Sleep -Milliseconds 40 }
    }
    if (-not $moved) { throw 'No se pudo persistir la cola de descargas.' }
    return $path
}

function Initialize-SQLPrimeDownloadQueue {
    param(
        [Parameter(Mandatory = $true)][object[]]$Targets,
        [string]$BaseDir = (Split-Path $PSScriptRoot -Parent),
        [switch]$ResetStates
    )
    $previous = if ($ResetStates) { @() } else { @(Get-SQLPrimeDownloadQueue -BaseDir $BaseDir) }
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $entries = foreach ($t in $Targets) {
        $state = 'Pending'
        if (-not $ResetStates) {
            $old = @($previous | Where-Object { $_.Name -eq [string]$t.Name })[0]
            if ($null -ne $old -and $old.State -in @('Paused', 'Cancelled')) { $state = [string]$old.State }
        }
        [pscustomobject]@{
            Name          = [string]$t.Name
            Url           = [string]$t.Url
            Path          = [string]$t.Path
            FinalPath     = [string]$t.FinalPath
            Dir           = [string]$t.Dir
            ExpectedBytes = [int64]$t.ExpectedSize
            ResumeBytes   = [int64]$t.ResumeBytes
            Bytes         = [int64]$t.ResumeBytes
            Total         = [int64]$t.ExpectedSize
            State         = $state
            Attempt       = 0
            SpeedBps      = [double]0
            EtaSeconds    = [int]0
            LastError     = ''
            UpdatedAtUtc  = $now
        }
    }
    $path = Save-SQLPrimeDownloadQueue -Entries @($entries) -BaseDir $BaseDir
    return $path
}

function Set-SQLPrimeDownloadQueueState {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('Pending','Downloading','Paused','Completed','Error','Cancelled')][string]$State,
        [string]$BaseDir = (Split-Path $PSScriptRoot -Parent),
        [long]$Bytes = -1,
        [long]$Total = -1,
        [double]$SpeedBps = -1,
        [int]$EtaSeconds = -1,
        [string]$LastError = ''
    )

    $entries = @(Get-SQLPrimeDownloadQueue -BaseDir $BaseDir)
    $found = $false
    foreach ($e in $entries) {
        if ($e.Name -eq $Name) {
            $e.State = $State
            if ($Bytes -ge 0) { $e.Bytes = [int64]$Bytes }
            if ($Total -ge 0) { $e.Total = [int64]$Total }
            if ($SpeedBps -ge 0) { $e.SpeedBps = [double]$SpeedBps }
            if ($EtaSeconds -ge 0) { $e.EtaSeconds = [int]$EtaSeconds }
            if ($State -eq 'Error' -or $State -eq 'Cancelled') { $e.LastError = $LastError }
            if ($State -eq 'Completed') { $e.Bytes = [int64]$e.Total; $e.SpeedBps = 0; $e.EtaSeconds = 0 }
            $e.UpdatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            $found = $true
            break
        }
    }
    if (-not $found) { return $null }
    Save-SQLPrimeDownloadQueue -Entries $entries -BaseDir $BaseDir | Out-Null
    return ($entries | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
}

function Get-SQLPrimeDownloadQueueDecision {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$BaseDir = (Split-Path $PSScriptRoot -Parent)
    )
    $entry = @(Get-SQLPrimeDownloadQueue -BaseDir $BaseDir | Where-Object { $_.Name -eq $Name })[0]
    if ($null -eq $entry) { return 'run' }
    if ($entry.State -in @('Paused', 'Cancelled')) { return 'skip' }
    return 'run'
}

function Get-SQLPrimeDownloadQueueStats {
    param([string]$BaseDir = (Split-Path $PSScriptRoot -Parent))
    $entries = @(Get-SQLPrimeDownloadQueue -BaseDir $BaseDir)
    return [pscustomobject]@{
        Total     = $entries.Count
        Pending   = @($entries | Where-Object { $_.State -eq 'Pending' }).Count
        Running   = @($entries | Where-Object { $_.State -eq 'Downloading' }).Count
        Paused    = @($entries | Where-Object { $_.State -eq 'Paused' }).Count
        Completed = @($entries | Where-Object { $_.State -eq 'Completed' }).Count
        Error     = @($entries | Where-Object { $_.State -eq 'Error' }).Count
    }
}
