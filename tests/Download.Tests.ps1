#Requires -Modules Pester
Describe 'Download module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Download.ps1')
    }

    It 'builds download targets and skips present files' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        try {
            $defs = @(
                @{ Major='10.50'; SPNumber=3; SP='SP3'; KB='2979597' }
            )
            $known = @{ 'SQLServer2008R2SP3-KB2979597-x64-ENU.exe' = 100 }
            # Pre-create x64 as complete
            $dir = Join-Path $tmp 'Instaladores\SQL Server 2008 R2 (10.50)\ServicePacks\SP3\x64\ENU'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [System.IO.File]::WriteAllBytes((Join-Path $dir 'SQLServer2008R2SP3-KB2979597-x64-ENU.exe'), [byte[]](0..99))

            $r = Get-SQLPrimeDownloadTargets -Definitions $defs -Lang 'ENU' -BaseDir $tmp -Inventory @() -KnownSizes $known `
                -GetDirectUrl { param($d,$a,$l) "https://example.test/$($d.SP)-$a-$l.exe" } `
                -GetExpectedFileName { param($maj,$sp,$a,$l) "SQLServer2008R2SP$sp-KB2979597-$a-$l.exe" }

            $r.AlreadyPresent | Should -Contain 'SQLServer2008R2SP3-KB2979597-x64-ENU.exe'
            @($r.Targets).Count | Should -Be 1
            $r.Targets[0].Arch | Should -Be 'x86'
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'marks targets without direct URL as missingNoDirect' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        try {
            $defs = @(@{ Major='10.0'; SPNumber=3; SP='SP3'; KB='2546951' })
            $r = Get-SQLPrimeDownloadTargets -Definitions $defs -Lang 'ENU' -BaseDir $tmp -Inventory @() `
                -GetDirectUrl { param($d,$a,$l) $null } `
                -GetExpectedFileName { param($maj,$sp,$a,$l) "SQLServer2008SP$sp-KB2546951-$a-$l.exe" }
            @($r.Targets).Count | Should -Be 0
            @($r.MissingNoDirect).Count | Should -Be 2
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'detects incomplete final and .part resume bytes' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        try {
            $defs = @(@{ Major='10.0'; SPNumber=4; SP='SP4'; KB='2979596' })
            $name = 'SQLServer2008SP4-KB2979596-x64-ENU.exe'
            $dir = Join-Path $tmp 'Instaladores\SQLServer2008SP4'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [System.IO.File]::WriteAllBytes((Join-Path $dir $name), [byte[]](1..50))
            [System.IO.File]::WriteAllBytes((Join-Path $dir ($name + '.part')), [byte[]](1..20))
            $known = @{ $name = 100 }
            $r = Get-SQLPrimeDownloadTargets -Definitions $defs -Lang 'ENU' -BaseDir $tmp -Inventory @() -KnownSizes $known `
                -GetDirectUrl { param($d,$a,$l) 'https://example.test/file.exe' } `
                -GetExpectedFileName { param($maj,$sp,$a,$l) if ($a -eq 'x64') { 'SQLServer2008SP4-KB2979596-x64-ENU.exe' } else { 'SQLServer2008SP4-KB2979596-x86-ENU.exe' } }
            $t = @($r.Targets | Where-Object { $_.Name -eq $name } | Select-Object -First 1)
            $t | Should -Not -BeNullOrEmpty
            $t.IncompleteFinal | Should -BeTrue
            $t.ResumeBytes | Should -Be 20
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}
