#Requires -Modules Pester
Describe 'I18n module' {
    BeforeAll { . (Join-Path $PSScriptRoot '..\modules\I18n.ps1') }

    It 'returns key when missing' {
        (T-SQLPrime -Key 'missing.key' -Map @{}) | Should -Be 'missing.key'
    }

    It 'returns default when provided' {
        (T-SQLPrime -Key 'missing.key' -Map @{} -Default 'Fallback') | Should -Be 'Fallback'
    }

    It 'loads i18n map from config/i18n' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        $dir = Join-Path $tmp 'config\i18n'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        '{"app.title":"SQL PRIME","status.ready":"Listo"}' | Set-Content -LiteralPath (Join-Path $dir 'es.json') -Encoding UTF8
        try {
            $m = Get-SQLPrimeI18n -BaseDir $tmp -Language 'es'
            $m['app.title'] | Should -Be 'SQL PRIME'
            (T-SQLPrime -Key 'status.ready' -Map $m) | Should -Be 'Listo'
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}
