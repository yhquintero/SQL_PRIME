#Requires -Modules Pester
Describe 'Services module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Services.ps1')
    }

    It 'returns default instance candidates' {
        $c = @(Get-SQLServiceCandidates -Instance 'MSSQLSERVER')
        $c | Should -Contain 'MSSQLSERVER'
        $c | Should -Contain 'SQLSERVERAGENT'
        $c | Should -Contain 'MSSQLFDLauncher'
        $c | Should -Contain 'SQLBrowser'
    }

    It 'returns named instance candidates' {
        $c = @(Get-SQLServiceCandidates -Instance 'SQLEXPRESS')
        $c | Should -Contain 'MSSQL$SQLEXPRESS'
        $c | Should -Contain 'SQLSERVERAGENT$SQLEXPRESS'
        $c | Should -Not -Contain 'MSSQLSERVER'
    }

    It 'maps service states by name' {
        Mock Get-Service {
            @(
                [pscustomobject]@{ Name='MSSQLSERVER'; Status='Running' },
                [pscustomobject]@{ Name='SQLBrowser';  Status='Stopped' }
            )
        }
        $m = Get-SQLServiceStates -Instance 'MSSQLSERVER'
        $m.ContainsKey('MSSQLSERVER') | Should -BeTrue
        $m['MSSQLSERVER'].Status | Should -Be 'Running'
        $m['SQLBrowser'].Status  | Should -Be 'Stopped'
    }
}
