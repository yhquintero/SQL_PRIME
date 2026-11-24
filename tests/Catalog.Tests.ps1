#Requires -Modules Pester
Describe 'Catalog' {
    It 'catalog.json is valid and has required fields' {
        $path = Join-Path $PSScriptRoot '..\catalog\catalog.json'
        Test-Path -LiteralPath $path | Should -BeTrue
        $c = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $c.schemaVersion | Should -Be 1
        $c.installers.Count | Should -BeGreaterThan 0
        foreach ($i in $c.installers) {
            $i.name | Should -Not -BeNullOrEmpty
            $i.product | Should -Not -BeNullOrEmpty
            $i.sp | Should -Match '^SP\d+$'
            $i.arch | Should -BeIn @('x64','x86')
            $i.lang | Should -Not -BeNullOrEmpty
            $i.size | Should -BeGreaterThan 0
        }
    }
}
