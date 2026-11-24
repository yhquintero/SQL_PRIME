#Requires -Modules Pester
Describe 'Integrity module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Config.ps1')
        . (Join-Path $PSScriptRoot '..\modules\Integrity.ps1')
    }

    It 'computes SHA256 for a file' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sqlprime-" + [guid]::NewGuid().ToString() + '.txt')
        'hello-sql-prime' | Out-File -FilePath $tmp -Encoding ascii -NoNewline
        try {
            $hash = Get-SQLPrimeFileSHA256 -Path $tmp
            $hash | Should -Match '^[a-f0-9]{64}$'
        } finally { Remove-Item -LiteralPath $tmp -Force }
    }

    It 'validates expected size and hash' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sqlprime-" + [guid]::NewGuid().ToString() + '.bin')
        [System.IO.File]::WriteAllBytes($tmp, [byte[]](1..32))
        try {
            $hash = Get-SQLPrimeFileSHA256 -Path $tmp
            $ok = Test-SQLPrimeFileIntegrity -Path $tmp -ExpectedSha256 $hash -ExpectedSize 32
            $ok.IsValid | Should -BeTrue
            $ok.HashChecked | Should -BeTrue
            $bad = Test-SQLPrimeFileIntegrity -Path $tmp -ExpectedSha256 ('0' * 64) -ExpectedSize 32
            $bad.IsValid | Should -BeFalse
            $bad.HashOk | Should -BeFalse
        } finally { Remove-Item -LiteralPath $tmp -Force }
    }
}
