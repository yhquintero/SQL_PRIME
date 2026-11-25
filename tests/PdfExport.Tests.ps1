#Requires -Modules Pester
Describe 'PDF export (Edge headless)' {
    BeforeAll {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $script:exporter = Join-Path $repoRoot 'scripts\Export-SQLPrimePdf.ps1'
        $script:edge = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    }

    It 'requires an existing HTML input' {
        { & $script:exporter -HtmlPath (Join-Path ([System.IO.Path]::GetTempPath()) 'no-existe.html') -EdgePath $script:edge } |
            Should -Throw
    }

    It 'generates a valid PDF from a report' {
        if (-not $script:edge) { Set-ItResult -Skipped -Because 'Microsoft Edge/Chrome no está instalado' }
        $html = @'
<!doctype html><html><head><meta charset="utf-8"><title>Prueba</title></head><body><h1>SQL PRIME</h1><p>Export PDF</p></body></html>
'@
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        try {
            $htmlPath = Join-Path $tmp 'test.html'
            $pdfPath = Join-Path $tmp 'test.pdf'
            [System.IO.File]::WriteAllText($htmlPath, $html)
            & $script:exporter -HtmlPath $htmlPath -OutputPath $pdfPath -EdgePath $script:edge | Out-Null
            Test-Path -LiteralPath $pdfPath | Should -BeTrue
            $bytes = [System.IO.File]::ReadAllBytes($pdfPath)[0..4]
            [System.Text.Encoding]::ASCII.GetString($bytes) | Should -Be '%PDF-'
        } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
