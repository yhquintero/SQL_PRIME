#Requires -Modules Pester
Describe 'Authenticode module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Authenticode.ps1')
    }

    It 'returns Exists=false for missing file' {
        $r = Test-SQLPrimeAuthenticode -Path (Join-Path $env:TEMP 'no-such-file-sqlprime.exe')
        $r.Exists | Should -BeFalse
        $r.IsTrusted | Should -BeFalse
    }
}
