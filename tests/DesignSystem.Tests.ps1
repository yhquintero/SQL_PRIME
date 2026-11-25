#Requires -Modules Pester
Describe 'Design system tokens' {
    BeforeAll {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        . (Join-Path $repoRoot 'modules\DesignSystem.ps1')
    }

    It 'exposes the dark HUD gradient in order' {
        $tokens = Get-SQLPrimeDesignTokens -Theme Dark
        @($tokens.progress) | Should -Be @('#00F5FF', '#7C4DFF', '#FF3DFF')
    }

    It 'exposes a high-contrast light gradient' {
        $tokens = Get-SQLPrimeDesignTokens -Theme Light
        @($tokens.progress) | Should -Be @('#0284C7', '#6366F1', '#D946EF')
    }

    It 'exports CSS variables for HTML reports' {
        $vars = ConvertTo-SQLPrimeCssVariables
        $vars | Should -Match '--cyan:#22d3ee'
        $vars | Should -Match '--violet:#8b5cf6'
        $vars | Should -Match '--pink:#f472b6'
    }
}
