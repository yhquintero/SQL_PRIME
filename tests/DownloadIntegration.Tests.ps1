#Requires -Modules Pester
Describe 'Download integration (mocked URL provider + .part states)' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Download.ps1')

        function New-DownloadFixture {
            param([string]$Name, [int]$FinalBytes = -1, [int]$PartBytes = -1, [string]$Folder = 'SQLServer2008SP4')

            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null
            $dir = Join-Path $tmp (Join-Path 'Instaladores' $Folder)
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            if ($FinalBytes -ge 0) { [System.IO.File]::WriteAllBytes((Join-Path $dir $Name), [byte[]](1..$FinalBytes)) }
            if ($PartBytes -ge 0) { [System.IO.File]::WriteAllBytes((Join-Path $dir ($Name + '.part')), [byte[]](1..$PartBytes)) }
            return $tmp
        }
    }

    It 'resumes from .part when final file is absent' {
        $name = 'SQLServer2008SP4-KB2979596-x64-ENU.exe'
        $tmp = New-DownloadFixture -Name $name -PartBytes 30
        try {
            $r = Get-SQLPrimeDownloadTargets -Definitions @(@{ Major='10.0'; SPNumber=4; SP='SP4'; KB='2979596' }) -Lang 'ENU' -BaseDir $tmp -Inventory @() -KnownSizes @{ $name = 100 } `
                -GetDirectUrl { param($d,$a,$l) "https://mock.invalid/$($d.SP)-$a-$l.exe" } `
                -GetExpectedFileName { param($maj,$sp,$a,$l) "SQLServer2008SP4-KB2979596-$a-$l.exe" }
            $t = @($r.Targets | Where-Object { $_.Name -eq $name })
            $t.Count | Should -Be 1
            $t[0].ResumeBytes | Should -Be 30
            $t[0].IncompleteFinal | Should -BeFalse
            $t[0].Path | Should -Be ((Join-Path $tmp 'Instaladores\SQLServer2008SP4') + "\" + $name + '.part')
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'detects incomplete final and preserves .part bytes when server must be asked to resume' {
        $name = 'SQLServer2008SP4-KB2979596-x64-ENU.exe'
        $tmp = New-DownloadFixture -Name $name -FinalBytes 50 -PartBytes 20
        try {
            $r = Get-SQLPrimeDownloadTargets -Definitions @(@{ Major='10.0'; SPNumber=4; SP='SP4'; KB='2979596' }) -Lang 'ENU' -BaseDir $tmp -Inventory @() -KnownSizes @{ $name = 100 } `
                -GetDirectUrl { param($d,$a,$l) 'https://mock.invalid/file.exe' } `
                -GetExpectedFileName { param($maj,$sp,$a,$l) "SQLServer2008SP4-KB2979596-$a-$l.exe" }
            $t = @($r.Targets | Where-Object { $_.Name -eq $name })
            $t[0].IncompleteFinal | Should -BeTrue
            $t[0].ResumeBytes | Should -Be 20
            $t[0].ExpectedSize | Should -Be 100
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'treats an existing file as complete when expected size is unknown' {
        $name = 'SQLServer2008SP4-KB2979596-x64-ENU.exe'
        $tmp = New-DownloadFixture -Name $name -FinalBytes 12
        try {
            $r = Get-SQLPrimeDownloadTargets -Definitions @(@{ Major='10.0'; SPNumber=4; SP='SP4'; KB='2979596' }) -Lang 'ENU' -BaseDir $tmp -Inventory @() -KnownSizes @{} `
                -GetDirectUrl { param($d,$a,$l) 'https://mock.invalid/file.exe' } `
                -GetExpectedFileName { param($maj,$sp,$a,$l) "SQLServer2008SP4-KB2979596-$a-$l.exe" }
            @($r.Targets | Where-Object { $_.Name -eq $name }).Count | Should -Be 0
            $r.AlreadyPresent | Should -Contain $name
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'honours the inventory folder when deciding whether a package is already present' {
        $name = 'SQLServer2008SP4-KB2979596-x64-ENU.exe'
        $tmp = New-DownloadFixture -Name $name -FinalBytes 100 -Folder 'InventarioPersonalizado'
        try {
            $inventory = @([pscustomobject]@{
                Name = $name; Major = '10.0'; SPNumber = 4; Arch = 'x64'; Lang = 'ENU'
                FolderPath = (Join-Path $tmp 'Instaladores\InventarioPersonalizado')
            })
            $r = Get-SQLPrimeDownloadTargets -Definitions @(@{ Major='10.0'; SPNumber=4; SP='SP4'; KB='2979596' }) -Lang 'ENU' -BaseDir $tmp -Inventory $inventory -KnownSizes @{ $name = 100 } `
                -GetDirectUrl { param($d,$a,$l) 'https://mock.invalid/file.exe' } `
                -GetExpectedFileName { param($maj,$sp,$a,$l) "SQLServer2008SP4-KB2979596-$a-$l.exe" }
            $r.AlreadyPresent | Should -Contain $name
            @($r.Targets | Where-Object { $_.Name -eq $name }).Count | Should -Be 0
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}
