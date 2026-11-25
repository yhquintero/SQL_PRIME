# SQL PRIME - Wizard state helpers (Phase 1 foundation)

function New-SQLPrimeWizardState {
    return [pscustomobject]@{
        Steps = @('Diagnosticar','Respaldar','Aplicar','Verificar')
        CurrentStep = 'Diagnosticar'
        Completed = @()
        History = @()
    }
}

function Step-SQLPrimeWizard {
    param(
        [Parameter(Mandatory=$true)]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Diagnosticar','Respaldar','Aplicar','Verificar')]$Step,
        [ValidateSet('Pending','Running','Done','Failed','Skipped')]$Status = 'Done'
    )
    $steps = @($State.Steps)
    $idx = [array]::IndexOf($steps, $Step)
    if ($idx -lt 0) { throw "Unknown step: $Step" }
    # Allow same or next step; allow backtracking to Diagnosticar
    $currentIdx = [array]::IndexOf($steps, $State.CurrentStep)
    if ($idx -gt $currentIdx + 1 -and $Step -ne 'Diagnosticar') {
        throw "Invalid transition: $($State.CurrentStep) -> $Step"
    }
    $entry = [pscustomobject]@{ Step=$Step; Status=$Status; At=(Get-Date).ToString('o') }
    $State.History += $entry
    if ($Status -eq 'Done') {
        if ($State.Completed -notcontains $Step) { $State.Completed += $Step }
        $next = $idx + 1
        if ($next -lt $steps.Count) { $State.CurrentStep = $steps[$next] }
        else { $State.CurrentStep = $Step }
    } elseif ($Status -eq 'Failed') {
        $State.CurrentStep = $Step
    }
    return $State
}

function Get-SQLPrimeWizardPreviousState {
    param([Parameter(Mandatory=$true)]$State)
    $steps = @($State.Steps)
    $idx = [array]::IndexOf($steps, $State.CurrentStep)
    if ($idx -le 0) { return $State }
    # Rebuild the state up to the previous step using the same validated transitions.
    $rebuilt = New-SQLPrimeWizardState
    for ($i = 0; $i -lt ($idx - 1); $i++) {
        $rebuilt = Step-SQLPrimeWizard -State $rebuilt -Step $steps[$i] -Status 'Done'
    }
    return $rebuilt
}
