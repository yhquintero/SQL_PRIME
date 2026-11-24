#Requires -Modules Pester
Describe 'Inventory module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Inventory.ps1')
    }

    It 'parses installer filenames into inventory objects' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        $dir = Join-Path $tmp 'SQL Server 2008 R2 (10.50)\ServicePacks\SP3\x64\ENU'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $f = Join-Path $dir 'SQLServer2008R2SP3-KB2979597-x64-ENU.exe'
        [System.IO.File]::WriteAllBytes($f, [byte[]](1..10))
        try {
            $inv = @(Get-InstallerInventory -BaseDir $tmp)
            $inv.Count | Should -Be 1
            $inv[0].Major | Should -Be '10.50'
            $inv[0].SPNumber | Should -Be 3
            $inv[0].Arch | Should -Be 'x64'
            $inv[0].Lang | Should -Be 'ENU'
            $inv[0].LocationOK | Should -BeTrue
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'Find-Installer returns matching language only' {
        $inv = @([pscustomobject]@{ Major='10.50'; SPNumber=3; Arch='x64'; Lang='ESN'; Name='x.exe' })
        $r = Find-Installer -MajorVersion '10.50' -SPNumber 3 -Arch 'x64' -Lang 'ENU' -Inventory $inv
        $r | Should -BeNullOrEmpty
    }
}
