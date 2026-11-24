# SQL PRIME - Detection helpers (Phase 0 extraction)

# Resolución pura de build -> SP/producto, testeable sin registro.
function Resolve-SQLBuildInfo {
    param(
        [Parameter(Mandatory=$true)][string]$Build,
        [string]$MajorVersion = '',
        [object[]]$BuildMap = @()
    )

    $parts = $Build.Split('.')
    if ($parts.Count -lt 3) { return $null }
    $major = if ($MajorVersion) { $MajorVersion } else { "$($parts[0]).$($parts[1])" }
    $buildNum = 0
    [void][int]::TryParse($parts[2], [ref]$buildNum)

    $result = [pscustomobject]@{
        MajorVersion = $major
        Build        = $Build
        BuildNumber  = $buildNum
        ProductName  = "SQL Server $major"
        SPLevel      = "Build $buildNum"
    }

    if ($major -eq '10.0') {
        $result.ProductName = 'SQL Server 2008'
        if ($buildNum -ge 6000) { $result.SPLevel = 'SP4' }
        elseif ($buildNum -ge 5500) { $result.SPLevel = 'SP3' }
        elseif ($buildNum -ge 4000) { $result.SPLevel = 'SP2' }
        elseif ($buildNum -ge 2531) { $result.SPLevel = 'SP1' }
        else { $result.SPLevel = 'RTM' }
        return $result
    }
    if ($major -eq '10.50') {
        $result.ProductName = 'SQL Server 2008 R2'
        if ($buildNum -ge 6000) { $result.SPLevel = 'SP3' }
        elseif ($buildNum -ge 4000) { $result.SPLevel = 'SP2' }
        elseif ($buildNum -ge 2500) { $result.SPLevel = 'SP1' }
        else { $result.SPLevel = 'RTM' }
        return $result
    }

    $map = @($BuildMap | Where-Object { $_.Prefix -eq $major } | Select-Object -First 1)
    if ($map.Count -gt 0) {
        $m = $map[0]
        $result.ProductName = $m.Name
        $spFound = @($m.SPs | Where-Object { $buildNum -ge $_.Min } | Select-Object -First 1)
        $result.SPLevel = if ($spFound.Count -gt 0) { $spFound[0].Label } else { 'RTM' }
    }
    return $result
}

# Detecta si la rama MSI es QFE/CU vs GDR.
function Test-SQLPrimeQfeBranch {
    param([string]$MajorVersion, [string]$ProductVersion)
    if (-not $MajorVersion -or -not $ProductVersion) { return $false }
    if ($ProductVersion -match '^(\d+)\.(\d+)\.') {
        $msiMajor = "$($matches[1]).$($matches[2])"
        return ($msiMajor -ne $MajorVersion)
    }
    return $false
}
