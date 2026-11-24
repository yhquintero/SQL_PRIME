#Requires -Modules Pester
Describe 'Validate-Catalog script' {
    It 'validates the repository catalog successfully' {
        $scriptPath = Join-Path $PSScriptRoot '..\scripts\Validate-Catalog.ps1'
        $catalogPath = Join-Path $PSScriptRoot '..\catalog\catalog.json'
        { & $scriptPath -CatalogPath $catalogPath } | Should -Not -Throw
    }
}
