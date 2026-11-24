# SQL PRIME - i18n helpers (Phase 1 foundation)

function Get-SQLPrimeI18n {
    param(
        [string]$BaseDir = $PSScriptRoot,
        [ValidateSet('es','en')][string]$Language = 'es'
    )
    $path = Join-Path $BaseDir "config\i18n\$Language.json"
    if (-not (Test-Path -LiteralPath $path)) {
        $path = Join-Path $BaseDir "i18n\$Language.json"
    }
    if (-not (Test-Path -LiteralPath $path)) { return @{} }
    try {
        $obj = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $map = @{}
        foreach ($p in $obj.PSObject.Properties) { $map[$p.Name] = [string]$p.Value }
        return $map
    } catch { return @{} }
}

function T-SQLPrime {
    param(
        [Parameter(Mandatory=$true)][string]$Key,
        [hashtable]$Map = @{},
        [string]$Default = ''
    )
    if ($Map -and $Map.ContainsKey($Key)) { return [string]$Map[$Key] }
    if ($Default) { return $Default }
    return $Key
}
