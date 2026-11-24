#Requires -Modules Pester
Describe 'Wizard module' {
    BeforeAll { . (Join-Path $PSScriptRoot '..\modules\Wizard.ps1') }

    It 'creates default wizard state' {
        $s = New-SQLPrimeWizardState
        $s.CurrentStep | Should -Be 'Diagnosticar'
        @($s.Steps).Count | Should -Be 4
    }

    It 'advances on Done and records history' {
        $s = New-SQLPrimeWizardState
        $s = Step-SQLPrimeWizard -State $s -Step 'Diagnosticar' -Status 'Done'
        $s.CurrentStep | Should -Be 'Respaldar'
        $s.Completed | Should -Contain 'Diagnosticar'
        @($s.History).Count | Should -Be 1
    }

    It 'rejects skipping steps' {
        $s = New-SQLPrimeWizardState
        { Step-SQLPrimeWizard -State $s -Step 'Aplicar' -Status 'Done' } | Should -Throw
    }

    It 'stays on failed step' {
        $s = New-SQLPrimeWizardState
        $s = Step-SQLPrimeWizard -State $s -Step 'Diagnosticar' -Status 'Failed'
        $s.CurrentStep | Should -Be 'Diagnosticar'
        $s.Completed | Should -Not -Contain 'Diagnosticar'
    }
}
