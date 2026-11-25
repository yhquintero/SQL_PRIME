#Requires -Modules Pester
Describe 'Persistent download queue' {
    BeforeAll {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        . (Join-Path $repoRoot 'modules\DownloadQueue.ps1')
        $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tmp -Force | Out-Null
        $script:targets = @(
            [pscustomobject]@{ Name = 'a.exe'; Url = 'https://mock.invalid/a'; Path = 'a.exe.part'; FinalPath = 'a.exe'; Dir = '.'; ExpectedSize = 1000; ResumeBytes = 100 },
            [pscustomobject]@{ Name = 'b.exe'; Url = 'https://mock.invalid/b'; Path = 'b.exe.part'; FinalPath = 'b.exe'; Dir = '.'; ExpectedSize = 2000; ResumeBytes = 0 }
        )
    }

    AfterAll { Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }

    It 'initializes pending entries with resume bytes' {
        Initialize-SQLPrimeDownloadQueue -Targets $script:targets -BaseDir $script:tmp | Out-Null
        $q = @(Get-SQLPrimeDownloadQueue -BaseDir $script:tmp)
        $q.Count | Should -Be 2
        $q[0].State | Should -Be 'Pending'
        $q[0].Bytes | Should -Be 100
        $q[0].ExpectedBytes | Should -Be 1000
    }

    It 'updates state, speed and ETA for one file' {
        $e = Set-SQLPrimeDownloadQueueState -Name 'a.exe' -State 'Downloading' -BaseDir $script:tmp -Bytes 500 -Total 1000 -SpeedBps 250 -EtaSeconds 2
        $e.State | Should -Be 'Downloading'
        $e.SpeedBps | Should -Be 250
        $e.EtaSeconds | Should -Be 2
    }

    It 'returns skip decision for paused or cancelled files' {
        Set-SQLPrimeDownloadQueueState -Name 'b.exe' -State 'Paused' -BaseDir $script:tmp | Out-Null
        Get-SQLPrimeDownloadQueueDecision -Name 'b.exe' -BaseDir $script:tmp | Should -Be 'skip'
        Get-SQLPrimeDownloadQueueDecision -Name 'a.exe' -BaseDir $script:tmp | Should -Be 'run'
    }

    It 'reports stats and completes a file with full bytes' {
        Set-SQLPrimeDownloadQueueState -Name 'a.exe' -State 'Completed' -BaseDir $script:tmp | Out-Null
        $stats = Get-SQLPrimeDownloadQueueStats -BaseDir $script:tmp
        $stats.Completed | Should -Be 1
        $stats.Paused | Should -Be 1
        $a = @(Get-SQLPrimeDownloadQueue -BaseDir $script:tmp | Where-Object { $_.Name -eq 'a.exe' })[0]
        $a.Bytes | Should -Be 1000
        $a.EtaSeconds | Should -Be 0
    }

    It 'returns run for an unknown file' {
        Get-SQLPrimeDownloadQueueDecision -Name 'desconocido.exe' -BaseDir $script:tmp | Should -Be 'run'
    }
}
