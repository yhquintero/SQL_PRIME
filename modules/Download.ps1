# SQL PRIME - Download helpers (Phase 0 extraction)

# Construye la lista de objetivos de descarga (testeable, sin UI/red).
function Get-SQLPrimeDownloadTargets {
    param(
        [Parameter(Mandatory=$true)][object[]]$Definitions,
        [Parameter(Mandatory=$true)][string]$Lang,
        [Parameter(Mandatory=$true)][string]$BaseDir,
        [object[]]$Inventory = @(),
        [hashtable]$KnownSizes = @{},
        [scriptblock]$GetDirectUrl = $null,
        [scriptblock]$GetExpectedFileName = $null
    )

    $targets = @()
    $missingNoDirect = @()
    $alreadyPresent = @()

    foreach ($def in $Definitions) {
        $family = if ($def.Major -eq '10.50') { 'SQLServer2008R2' } else { 'SQLServer2008' }
        foreach ($arch in @('x64','x86')) {
            $url = $null
            $name = $null
            if ($GetDirectUrl) { $url = & $GetDirectUrl $def $arch $Lang }
            if ($GetExpectedFileName) { $name = & $GetExpectedFileName $def.Major $def.SPNumber $arch $Lang }
            if (-not $name) { continue }

            $sameFile = @($Inventory | Where-Object {
                $_.Major -eq $def.Major -and $_.SPNumber -eq $def.SPNumber -and
                $_.Arch -eq $arch -and $_.Lang -eq $Lang
            })
            $versionFolder = if ($def.Major -eq '10.50') { 'SQL Server 2008 R2 (10.50)' } else { 'SQL Server 2008 (10.0)' }
            $installersRoot = Join-Path $BaseDir 'Instaladores'
            $structuredDir = Join-Path $installersRoot "$versionFolder\ServicePacks\SP$($def.SPNumber)\$arch\$Lang"
            $sameSP = @($Inventory | Where-Object { $_.Major -eq $def.Major -and $_.SPNumber -eq $def.SPNumber })

            $folderPath = if ($sameFile.Count -gt 0) {
                $sameFile[0].FolderPath
            } elseif (Test-Path -LiteralPath $structuredDir) {
                $structuredDir
            } elseif ($sameSP.Count -gt 0) {
                $sameSP[0].FolderPath
            } else {
                Join-Path $installersRoot "$($family)SP$($def.SPNumber)"
            }

            $finalPath = Join-Path $folderPath $name
            $partPath = "$finalPath.part"
            $expectedSize = [int64]0
            if ($KnownSizes -and $KnownSizes.ContainsKey($name)) { $expectedSize = [int64]$KnownSizes[$name] }

            $isComplete = $false
            if (Test-Path -LiteralPath $finalPath) {
                $actual = [int64](Get-Item -LiteralPath $finalPath).Length
                if ($expectedSize -gt 0 -and $actual -lt $expectedSize) {
                    # incompleto: debe reanudarse
                } else {
                    $isComplete = $true
                }
            }
            if ($isComplete) {
                $alreadyPresent += $name
                continue
            }

            if (-not $url) {
                $missingNoDirect += $name
                continue
            }

            $resumeBytes = [int64]0
            $hasIncompleteFinal = $false
            if (Test-Path -LiteralPath $finalPath) {
                $actualFinal = [int64](Get-Item -LiteralPath $finalPath).Length
                if ($expectedSize -gt 0 -and $actualFinal -lt $expectedSize) { $hasIncompleteFinal = $true }
            }
            if (Test-Path -LiteralPath $partPath) { $resumeBytes = [int64](Get-Item -LiteralPath $partPath).Length }

            $targets += [pscustomobject]@{
                Name             = $name
                Url              = $url
                Path             = $partPath
                FinalPath        = $finalPath
                Dir              = $folderPath
                SP               = $def.SP
                Major            = $def.Major
                Arch             = $arch
                Lang             = $Lang
                ResumeBytes      = $resumeBytes
                ExpectedSize     = $expectedSize
                IncompleteFinal  = $hasIncompleteFinal
            }
        }
    }

    return [pscustomobject]@{
        Targets          = @($targets)
        MissingNoDirect  = @($missingNoDirect)
        AlreadyPresent   = @($alreadyPresent)
    }
}
