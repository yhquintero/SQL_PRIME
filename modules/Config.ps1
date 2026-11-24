# SQL PRIME - Config management (Phase 0)

function Get-SQLPrimeDefaultConfig {
    return @{
        schemaVersion = 1
        app = @{ name = 'SQL PRIME'; channel = 'stable' }
        logging = @{ level = 'INFO'; jsonlEnabled = $true; maxSizeMB = 10; retainFiles = 5 }
        downloads = @{ verifySha256 = $true; allowUnverifiedWhenHashMissing = $true; maxConcurrent = 1; retryCount = 2 }
        security = @{ requireAdminForChanges = $true; verifyAuthenticode = $false }
    }
}

function Merge-SQLPrimeConfig {
    param([hashtable]$Default, [hashtable]$Override)
    $result = @{}
    foreach ($k in $Default.Keys) {
        if ($Override.ContainsKey($k) -and $Default[$k] -is [hashtable] -and $Override[$k] -is [hashtable]) {
            $result[$k] = Merge-SQLPrimeConfig -Default $Default[$k] -Override $Override[$k]
        } elseif ($Override.ContainsKey($k)) {
            $result[$k] = $Override[$k]
        } else {
            $result[$k] = $Default[$k]
        }
    }
    foreach ($k in $Override.Keys) {
        if (-not $result.ContainsKey($k)) { $result[$k] = $Override[$k] }
    }
    return $result
}

function ConvertTo-SQLPrimeHashtable {
    param($Object)
    if ($null -eq $Object) { return $null }
    if ($Object -is [hashtable]) { return $Object }
    if ($Object -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in $Object.Keys) { $h[$k] = ConvertTo-SQLPrimeHashtable $Object[$k] }
        return $h
    }
    if ($Object -is [psobject] -and $Object.PSObject.TypeNames[0] -ne 'System.String') {
        $h = @{}
        foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = ConvertTo-SQLPrimeHashtable $p.Value }
        if ($h.Count -gt 0) { return $h }
    }
    return $Object
}

function Get-SQLPrimeConfig {
    param([string]$BaseDir = (Split-Path $PSScriptRoot -Parent))
    $defaults = Get-SQLPrimeDefaultConfig
    $path = Join-Path $BaseDir 'config\app.config.json'
    if (-not (Test-Path -LiteralPath $path)) {
        $script:SQLPrimeConfig = $defaults
        return $script:SQLPrimeConfig
    }
    try {
        $raw = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $loaded = ConvertTo-SQLPrimeHashtable $raw
        if (-not ($loaded -is [hashtable])) { $loaded = @{} }
        $script:SQLPrimeConfig = Merge-SQLPrimeConfig -Default $defaults -Override $loaded
    } catch {
        $script:SQLPrimeConfig = $defaults
    }
    return $script:SQLPrimeConfig
}

function Save-SQLPrimeConfig {
    param([string]$BaseDir = (Split-Path $PSScriptRoot -Parent))
    if (-not $script:SQLPrimeConfig) { $script:SQLPrimeConfig = Get-SQLPrimeDefaultConfig }
    $path = Join-Path $BaseDir 'config\app.config.json'
    $dir = Split-Path $path -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $script:SQLPrimeConfig | ConvertTo-Json -Depth 8 | Out-File -FilePath $path -Encoding utf8 -Force
}
