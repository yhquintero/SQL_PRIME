# SQL PRIME - Design system tokens (centralized palette for UI and reports)

# Inicializar siempre para no fallar bajo Set-StrictMode al cargar desde un script host.
$script:SQLPrimeDesignSystem = $null
if (-not $script:SQLPrimeDesignSystem) {
    $designPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'config\design-system.json'
    if (Test-Path -LiteralPath $designPath) {
        try { $script:SQLPrimeDesignSystem = Get-Content -LiteralPath $designPath -Raw | ConvertFrom-Json }
        catch { $script:SQLPrimeDesignSystem = $null }
    }
}

function Get-SQLPrimeDesignTokens {
    param(
        [ValidateSet('Dark', 'Light', 'Auto')][string]$Theme = 'Dark',
        [string]$BaseDir = (Split-Path $PSScriptRoot -Parent)
    )

    if (-not $script:SQLPrimeDesignSystem) {
        $designPath = Join-Path $BaseDir 'config\design-system.json'
        if (Test-Path -LiteralPath $designPath) {
            try { $script:SQLPrimeDesignSystem = Get-Content -LiteralPath $designPath -Raw | ConvertFrom-Json }
            catch { return $null }
        } else { return $null }
    }

    $resolved = $Theme
    if ($Theme -eq 'Auto') {
        try {
            $reg = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction SilentlyContinue
            $resolved = if ($reg.AppsUseLightTheme -eq 1) { 'Light' } else { 'Dark' }
        } catch { $resolved = 'Dark' }
    }
    return $script:SQLPrimeDesignSystem.themes.$resolved
}

function Get-SQLPrimeCssVariables {
    param([string]$BaseDir = (Split-Path $PSScriptRoot -Parent))

    if (-not $script:SQLPrimeDesignSystem) { $null = Get-SQLPrimeDesignTokens -BaseDir $BaseDir }
    if (-not $script:SQLPrimeDesignSystem) { return @{} }
    $vars = @{}
    foreach ($p in $script:SQLPrimeDesignSystem.css.variables.PSObject.Properties) { $vars[$p.Name] = [string]$p.Value }
    return $vars
}

function ConvertTo-SQLPrimeCssVariables {
    param([string]$BaseDir = (Split-Path $PSScriptRoot -Parent))

    $vars = Get-SQLPrimeCssVariables -BaseDir $BaseDir
    if ($vars.Count -eq 0) {
        return '--bg:#070b18;--panel:#0f172a;--line:#22304d;--txt:#e6f1ff;--muted:#93a4c3;--cyan:#22d3ee;--violet:#8b5cf6;--pink:#f472b6;--green:#34d399;--amber:#fbbf24;--red:#fb7185'
    }
    return (($vars.GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)" }) -join ';')
}
