# SQL PRIME - Inventory helpers (Phase 0 extraction)

function Test-InstallerLocation {
    param([string]$Folder, [string]$Major, [int]$SPNumber, [string]$FullName)

    # 1) Carpetas heredadas: SQLServer2008SPn / SQLServer2008R2SPn
    $m = [regex]::Match($Folder, '^SQLServer2008(R2)?SP(\d+)$', 'IgnoreCase')
    if ($m.Success) {
        if ([int]$m.Groups[2].Value -ne $SPNumber) { return $false }
        $folderIsR2 = [bool]$m.Groups[1].Value
        if ($folderIsR2 -and $Major -ne "10.50") { return $false }
        return $true
    }

    # 2) Estructura profesional generada por CREAR CARPETAS:
    #    <SQL Server 2008 R2 (10.50)>\ServicePacks\SPn\<arquitectura>\<idioma>
    if ($FullName) {
        $path = $FullName -replace '\\', '/'
        $inR2   = $path -match '(?i)/SQL Server 2008 R2 \(10\.50\)/'
        $in2008 = $path -match '(?i)/SQL Server 2008 \(10\.0\)/'
        if ($inR2 -or $in2008) {
            if ($inR2 -ne ($Major -eq "10.50")) { return $false }
            return ($path -match "(?i)/ServicePacks/SP$SPNumber(/|$)")
        }
    }
    return $false
}

function Get-InstallerInventory {
    param([string]$BaseDir = $PSScriptRoot)

    # Se escanean TODAS las carpetas en profundidad y se clasifica por el NOMBRE
    # del fichero, no por la carpeta donde esté (las carpetas actuales mezclan
    # instaladores de 2008 y 2008 R2).
    $rx = '^SQLServer2008(R2)?SP(\d+)-KB(\d+)-(x86|x64|ia64)-([A-Za-z]{3})\.exe$'
    $files = Get-ChildItem -Path $BaseDir -Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -match $rx }

    $result = @()
    foreach ($f in $files) {
        if ($f.Name -notmatch $rx) { continue }
        $isR2     = [bool]$matches[1]
        $spNumber = [int]$matches[2]
        $kb       = $matches[3]
        $arch     = $matches[4].ToLower()
        $lang     = $matches[5].ToUpper()
        $major    = if ($isR2) { "10.50" } else { "10.0" }
        $family   = if ($isR2) { "SQLServer2008R2" } else { "SQLServer2008" }
        $expectedFolder = "$($family)SP$spNumber"

        $result += [pscustomobject]@{
            Name           = $f.Name
            FullName       = $f.FullName
            Folder         = $f.Directory.Name
            FolderPath     = $f.Directory.FullName
            Major          = $major
            SPNumber       = $spNumber
            SP             = "SP$spNumber"
            KB             = $kb
            Arch           = $arch
            Lang           = $lang
            SizeMB         = [math]::Round($f.Length / 1MB, 1)
            ExpectedFolder = $expectedFolder
            LocationOK     = (Test-InstallerLocation -Folder $f.Directory.Name -Major $major -SPNumber $spNumber -FullName $f.FullName)
            LegacyLayout   = ($isR2 -and $f.Directory.Name -match '^SQLServer2008SP\d+$')
        }
    }
    return @($result)
}

function Find-Installer {
    param([string]$MajorVersion, [int]$SPNumber, [string]$Arch, [string]$Lang, $Inventory)

    $candidates = @($Inventory | Where-Object {
        $_.Major -eq $MajorVersion -and $_.SPNumber -eq $SPNumber -and $_.Arch -eq $Arch
    })
    if ($candidates.Count -eq 0) { return $null }

    $preferred = @($candidates | Where-Object { $_.Lang -eq $Lang })
    if ($preferred.Count -gt 0) { return $preferred[0] }
    # NUNCA se devuelve un paquete de otro idioma: en una instalación LCID 1033
    # un instalador ESN no se aplica y provoca el error "No se actualizó ninguna característica".
    return $null
}

function Show-InventorySummary {
    if ($script:Inventory.Count -eq 0) {
        Update-UI -Log "INVENTARIO: no hay instaladores SQL 2008/R2 SP en las carpetas." -LogColor "#FFAA00"
        return
    }
    Update-UI -Log "=== INVENTARIO DE INSTALADORES ($($script:Inventory.Count) ficheros) ===" -LogColor "#00CCFF"
    foreach ($f in $script:Inventory) {
        if ($f.LocationOK -and $f.LegacyLayout) {
            $location = "carpeta heredada (válida)"
            $color = "#88CCFF"
        } elseif ($f.LocationOK) {
            $location = "ubicación OK"
            $color = "#00FFCC"
        } else {
            $location = "⚠ debería estar en '$($f.ExpectedFolder)'"
            $color = "#FFAA00"
        }
        $langMark = if ($f.Lang -eq "ESN" -and $script:PreferredLang -eq "ENU") { " [ESN: no aplica a LCID 1033]" } else { "" }
        Update-UI -Log ("  {0} [{1} {2} {3} {4} {5} MB] -> {6}{7}" -f $f.Name, $f.Major, $f.SP, $f.Arch, $f.Lang, $f.SizeMB, $location, $langMark) -LogColor $color
    }
}

