#Requires -Modules Pester
Describe 'Config module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Config.ps1')
    }

    It 'returns defaults when config file is missing' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            $cfg = Get-SQLPrimeConfig -BaseDir $tmp
            $cfg.schemaVersion | Should -Be 1
            $cfg.downloads.verifySha256 | Should -BeTrue
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }

    It 'merges overrides over defaults' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $tmp 'config') -Force | Out-Null
        '{"schemaVersion":1,"downloads":{"verifySha256":false,"retryCount":5}}' | Out-File -FilePath (Join-Path $tmp 'config\app.config.json') -Encoding utf8
        try {
            $cfg = Get-SQLPrimeConfig -BaseDir $tmp
            $cfg.downloads.verifySha256 | Should -BeFalse
            $cfg.downloads.retryCount | Should -Be 5
            $cfg.downloads.allowUnverifiedWhenHashMissing | Should -BeTrue
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}
