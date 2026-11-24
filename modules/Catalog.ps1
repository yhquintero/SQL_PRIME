# SQL PRIME - Catalog / SP definitions (Phase 0 extraction)

$script:SPDefinitions = @(
    @{ Major="10.0"; SPNumber=4; SP="SP4"; KB="2979596";
       Page="https://www.microsoft.com/en-us/download/details.aspx?id=44278";
       PageES="https://www.microsoft.com/es-es/download/details.aspx?id=44278";
       Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2979596";
       Support="https://support.microsoft.com/help/2979596";
       Direct=@{
           ENU=@{
             x64="https://download.microsoft.com/download/5/e/7/5e7a89f7-c013-4090-901e-1a0f86b6a94c/ENU/SQLServer2008SP4-KB2979596-x64-ENU.exe"
             x86="https://download.microsoft.com/download/5/e/7/5e7a89f7-c013-4090-901e-1a0f86b6a94c/ENU/SQLServer2008SP4-KB2979596-x86-ENU.exe"
           }
           ESN=@{
             x64="https://download.microsoft.com/download/d/a/b/dab85be8-45fe-4e8c-b80d-93dfe12b6913/ESN/SQLServer2008SP4-KB2979596-x64-ESN.exe"
             x86="https://download.microsoft.com/download/d/a/b/dab85be8-45fe-4e8c-b80d-93dfe12b6913/ESN/SQLServer2008SP4-KB2979596-x86-ESN.exe"
           }
       } },
    @{ Major="10.0"; SPNumber=3; SP="SP3"; KB="2546951";
       Page="https://www.catalog.update.microsoft.com/Search.aspx?q=2546951";
       Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2546951";
       Support="https://support.microsoft.com/help/2546951"; Direct=@{} },
    @{ Major="10.0"; SPNumber=2; SP="SP2"; KB="2285068";
       Page="https://www.catalog.update.microsoft.com/Search.aspx?q=2285068";
       Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2285068";
       Support="https://support.microsoft.com/help/2285068"; Direct=@{} },
    @{ Major="10.50"; SPNumber=3; SP="SP3"; KB="2979597";
       Page="https://www.microsoft.com/en-us/download/details.aspx?id=44271";
       PageES="https://www.microsoft.com/es-es/download/details.aspx?id=44271";
       Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2979597";
       Support="https://support.microsoft.com/help/2979597";
       Direct=@{
           ENU=@{
             x64="https://download.microsoft.com/download/d/7/a/d7a28b6c-fcfe-4f70-a902-b109388e01e9/ENU/SQLServer2008R2SP3-KB2979597-x64-ENU.exe"
             x86="https://download.microsoft.com/download/d/7/a/d7a28b6c-fcfe-4f70-a902-b109388e01e9/ENU/SQLServer2008R2SP3-KB2979597-x86-ENU.exe"
           }
           ESN=@{
             x64="https://download.microsoft.com/download/3/1/0/310b5c5a-2383-43cc-a018-671d197185b9/ESN/SQLServer2008R2SP3-KB2979597-x64-ESN.exe"
             x86="https://download.microsoft.com/download/3/1/0/310b5c5a-2383-43cc-a018-671d197185b9/ESN/SQLServer2008R2SP3-KB2979597-x86-ESN.exe"
           }
       } },
    @{ Major="10.50"; SPNumber=2; SP="SP2"; KB="2630458";
       Page="https://www.microsoft.com/en-us/download/details.aspx?id=30437";
       PageES="https://www.microsoft.com/es-es/download/details.aspx?id=30437";
       Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2630458";
       Support="https://support.microsoft.com/help/2630458";
       Direct=@{
           ENU=@{
             x64="https://download.microsoft.com/download/3/d/c/3dc6663d-8a76-40a6-bcf2-2808c385d56a/SQLServer2008R2SP2-KB2630458-x64-ENU.exe"
             x86="https://download.microsoft.com/download/3/d/c/3dc6663d-8a76-40a6-bcf2-2808c385d56a/SQLServer2008R2SP2-KB2630458-x86-ENU.exe"
           }
           ESN=@{
             x64="https://download.microsoft.com/download/f/1/c/f1c6bfa0-d9a6-4897-8e87-11e0703354b4/SQLServer2008R2SP2-KB2630458-x64-ESN.exe"
             x86="https://download.microsoft.com/download/f/1/c/f1c6bfa0-d9a6-4897-8e87-11e0703354b4/SQLServer2008R2SP2-KB2630458-x86-ESN.exe"
           }
       } },
    @{ Major="10.50"; SPNumber=1; SP="SP1"; KB="2528583";
       Page="https://www.catalog.update.microsoft.com/Search.aspx?q=2528583";
       Catalog="https://www.catalog.update.microsoft.com/Search.aspx?q=2528583";
       Support="https://support.microsoft.com/help/2528583"; Direct=@{} }
)

# Tamaños oficiales (Content-Length de download.microsoft.com) para validar y reanudar.
$script:KnownSizes = @{
    "SQLServer2008R2SP3-KB2979597-x64-ENU.exe" = 375792304
    "SQLServer2008R2SP3-KB2979597-x86-ENU.exe" = 259195056
    "SQLServer2008R2SP2-KB2630458-x64-ENU.exe" = 369585096
    "SQLServer2008R2SP2-KB2630458-x86-ENU.exe" = 253357488
    "SQLServer2008SP4-KB2979596-x64-ENU.exe"   = 396782240
    "SQLServer2008SP4-KB2979596-x86-ENU.exe"   = 326047912
}

function Get-KnownSize {
    param([string]$Name)
    if ($script:KnownSizes.ContainsKey($Name)) { return [int64]$script:KnownSizes[$Name] }
    return 0
}

function Get-SPDefinition {
    param([string]$MajorVersion, [int]$SPNumber)
    return ($script:SPDefinitions | Where-Object { $_.Major -eq $MajorVersion -and $_.SPNumber -eq $SPNumber } | Select-Object -First 1)
}

function Get-DirectUrl {
    param($Definition, [string]$Arch, [string]$Lang)
    if (-not $Definition -or -not $Definition.ContainsKey("Direct")) { return $null }
    $byLang = $Definition.Direct
    $langKey = @($byLang.Keys | Where-Object { $_ -ieq $Lang } | Select-Object -First 1)
    if ($langKey.Count -eq 0) { return $null }
    $byArch = $byLang[$langKey[0]]
    $archKey = @($byArch.Keys | Where-Object { $_ -ieq $Arch } | Select-Object -First 1)
    if ($archKey.Count -eq 0) { return $null }
    return $byArch[$archKey[0]]
}

function Get-DownloadPage {
    param($Definition, [string]$Lang)
    if ($Lang -ieq "ESN" -and $Definition.PageES) { return $Definition.PageES }
    if ($Definition.Page) { return $Definition.Page }
    return $Definition.Catalog
}

# LCID del registro -> sufijo de idioma usado por los instaladores de SQL Server.
function Get-LanguageCode {
    param($Lcid)
    $map = @{
        "1033"="ENU"; "3082"="ESN"; "1034"="ESN"; "1031"="DEU"; "1036"="FRA";
        "1040"="ITA"; "1041"="JPN"; "1042"="KOR"; "1045"="PLK"; "1046"="PTB";
        "2070"="PTG"; "1049"="RUS"; "1055"="TUR"; "1038"="HUN"; "1029"="CSY";
        "2052"="CHS"; "1028"="CHT"; "1043"="NLD"; "1053"="SVE"; "1030"="DAN";
        "1044"="NOR"; "1035"="FIN"; "1048"="ROU"; "1050"="HRV"; "1051"="SLK";
        "1060"="SLV"; "1032"="ELL"; "1054"="THA"; "1056"="ARA"; "1037"="HEB"
    }
    $key = "$Lcid".Trim()
    if ($map.ContainsKey($key)) { return $map[$key] }
    return $null
}

function Get-LanguageDisplayName {
    param($Lcid, [string]$Code)
    $names = @{
        "1033"="English - United States"; "3082"="Spanish - Spain (Modern)";
        "1034"="Spanish - Spain (Traditional)"; "1031"="German";
        "1036"="French"; "1040"="Italian"; "1041"="Japanese"; "1042"="Korean"
    }
    $key = "$Lcid".Trim()
    if ($names.ContainsKey($key)) { return "$($names[$key]) / $Code" }
    if ($Code) { return "$Code (LCID $Lcid)" }
    return "LCID $Lcid"
}

function Get-ExpectedFileName {
    param([string]$MajorVersion, [int]$SPNumber, [string]$Arch, [string]$Lang)
    $def = Get-SPDefinition -MajorVersion $MajorVersion -SPNumber $SPNumber
    $prefix = if ($MajorVersion -eq "10.50") { "SQLServer2008R2SP$SPNumber" } else { "SQLServer2008SP$SPNumber" }
    $kb = if ($def) { "KB$($def.KB)" } else { "KB" }
    return "$prefix-$kb-$Arch-$Lang.exe"
}
