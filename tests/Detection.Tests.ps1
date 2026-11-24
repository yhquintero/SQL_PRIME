#Requires -Modules Pester
Describe 'Detection module' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\modules\Detection.ps1')
    }

    It 'resolves SQL 2008 SP4 build' {
        $r = Resolve-SQLBuildInfo -Build '10.0.6000.29'
        $r.MajorVersion | Should -Be '10.0'
        $r.ProductName  | Should -Be 'SQL Server 2008'
        $r.SPLevel      | Should -Be 'SP4'
    }

    It 'resolves SQL 2008 R2 SP3 build' {
        $r = Resolve-SQLBuildInfo -Build '10.50.6000.34'
        $r.MajorVersion | Should -Be '10.50'
        $r.ProductName  | Should -Be 'SQL Server 2008 R2'
        $r.SPLevel      | Should -Be 'SP3'
    }

    It 'resolves SQL 2008 R2 RTM build' {
        $r = Resolve-SQLBuildInfo -Build '10.50.1600.1'
        $r.SPLevel | Should -Be 'RTM'
    }

    It 'resolves generic version using BuildMap' {
        $map = @(
            [pscustomobject]@{
                Prefix='15.0'; Name='SQL Server 2019';
                SPs=@([pscustomobject]@{ Label='CU28+GDR'; Min=4355 })
            }
        )
        $r = Resolve-SQLBuildInfo -Build '15.0.4355.3' -BuildMap $map
        $r.ProductName | Should -Be 'SQL Server 2019'
        $r.SPLevel     | Should -Be 'CU28+GDR'
    }

    It 'detects QFE/CU branch mismatch' {
        (Test-SQLPrimeQfeBranch -MajorVersion '10.50' -ProductVersion '10.52.4000.0') | Should -BeTrue
        (Test-SQLPrimeQfeBranch -MajorVersion '10.50' -ProductVersion '10.50.6000.34') | Should -BeFalse
    }
}
