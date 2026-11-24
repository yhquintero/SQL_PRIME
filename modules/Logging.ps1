# SQL PRIME - Structured logging (Phase 0)

function Initialize-SQLPrimeLogging {
    param(
        [string]$BaseDir = $PSScriptRoot
    )
    if (-not $script:SQLPrimeConfig) { $script:SQLPrimeConfig = Get-SQLPrimeConfig -BaseDir (Split-Path $BaseDir -Parent) }
    $root = Split-Path $BaseDir -Parent
    $logDir = Join-Path $root 'logs'
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $script:SQLPrimeJsonlPath = Join-Path $logDir 'sql_prime.jsonl'
    $script:SQLPrimeLogMaxBytes = [int64]([math]::Max(1, [int]$script:SQLPrimeConfig.logging.maxSizeMB) * 1MB)
    $script:SQLPrimeLogRetain = [int]([math]::Max(1, [int]$script:SQLPrimeConfig.logging.retainFiles))
}

function Invoke-SQLPrimeLogRotation {
    if (-not $script:SQLPrimeJsonlPath) { return }
    if (-not (Test-Path -LiteralPath $script:SQLPrimeJsonlPath)) { return }
    try {
        $item = Get-Item -LiteralPath $script:SQLPrimeJsonlPath -ErrorAction Stop
        if ($item.Length -lt $script:SQLPrimeLogMaxBytes) { return }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $archive = Join-Path (Split-Path $script:SQLPrimeJsonlPath -Parent) "sql_prime.$stamp.jsonl"
        Move-Item -LiteralPath $script:SQLPrimeJsonlPath -Destination $archive -Force
        $archives = @(Get-ChildItem -LiteralPath (Split-Path $archive -Parent) -Filter 'sql_prime.*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($archives.Count -gt $script:SQLPrimeLogRetain) {
            $archives | Select-Object -Skip $script:SQLPrimeLogRetain | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

function Write-SQLPrimeStructuredLog {
    param(
        [ValidateSet('DEBUG','INFO','WARN','ERROR','AUDIT')]
        [string]$Level = 'INFO',
        [Parameter(Mandatory=$true)][string]$Message,
        [string]$Component = 'app',
        [hashtable]$Data = @{},
        [string]$OperationId = ''
    )
    try {
        if (-not $script:SQLPrimeJsonlPath) { Initialize-SQLPrimeLogging -BaseDir $PSScriptRoot }
        if (-not $script:SQLPrimeConfig.logging.jsonlEnabled) { return }
        Invoke-SQLPrimeLogRotation
        $entry = [ordered]@{
            ts          = (Get-Date).ToString('o')
            level       = $Level
            component   = $Component
            operationId = $OperationId
            message     = $Message
            data        = $Data
        }
        $line = ($entry | ConvertTo-Json -Depth 6 -Compress)
        [System.IO.File]::AppendAllText($script:SQLPrimeJsonlPath, $line + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    } catch {
        # Logging nunca debe romper la app.
    }
}
