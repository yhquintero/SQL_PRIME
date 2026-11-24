# SQL PRIME - Integrity verification (Phase 0)

function Get-SQLPrimeFileSHA256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hashBytes = $sha.ComputeHash($stream)
        return ([BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
    } finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

function Get-SQLPrimeKnownHash {
    param([Parameter(Mandatory=$true)][string]$Name)
    $catalogPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog\catalog.json'
    if (Test-Path -LiteralPath $catalogPath) {
        try {
            $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
            $item = @($catalog.installers | Where-Object { $_.name -ieq $Name } | Select-Object -First 1)
            if ($item.Count -gt 0 -and $item[0].sha256) {
                $h = [string]$item[0].sha256
                if ($h -and $h.Length -eq 64) { return $h.ToLowerInvariant() }
            }
        } catch { }
    }
    if ($script:KnownHashes -and $script:KnownHashes.ContainsKey($Name)) {
        $h = [string]$script:KnownHashes[$Name]
        if ($h -and $h.Length -eq 64) { return $h.ToLowerInvariant() }
    }
    return $null
}

function Test-SQLPrimeFileIntegrity {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$ExpectedSha256 = '',
        [int64]$ExpectedSize = 0
    )
    $result = [pscustomobject]@{
        Path         = $Path
        Exists       = $false
        Size         = 0
        Sha256       = $null
        ExpectedSize = $ExpectedSize
        ExpectedSha256 = $ExpectedSha256
        SizeOk       = $true
        HashOk       = $true
        HashChecked  = $false
        IsValid      = $false
        Message      = ''
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        $result.Message = 'Archivo no existe'
        return $result
    }
    $item = Get-Item -LiteralPath $Path
    $result.Exists = $true
    $result.Size = [int64]$item.Length

    if ($ExpectedSize -gt 0) {
        $result.SizeOk = ($result.Size -eq $ExpectedSize)
        if (-not $result.SizeOk) { $result.Message = "Tamaño incorrecto: $($result.Size) != $ExpectedSize" }
    }

    $hashToCheck = $ExpectedSha256
    if (-not $hashToCheck) { $hashToCheck = Get-SQLPrimeKnownHash -Name $item.Name }
    if ($hashToCheck) {
        $result.ExpectedSha256 = $hashToCheck
        $result.Sha256 = Get-SQLPrimeFileSHA256 -Path $Path
        $result.HashChecked = $true
        $result.HashOk = ($result.Sha256 -eq $hashToCheck.ToLowerInvariant())
        if (-not $result.HashOk) { $result.Message = "SHA256 incorrecto para $($item.Name)" }
    } else {
        $result.Sha256 = Get-SQLPrimeFileSHA256 -Path $Path
    }

    $result.IsValid = ($result.SizeOk -and $result.HashOk)
    if ($result.IsValid -and -not $result.Message) { $result.Message = 'OK' }
    return $result
}
