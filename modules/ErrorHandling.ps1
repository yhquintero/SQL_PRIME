# SQL PRIME - Error handling / operation correlation (Phase 0)

function New-SQLPrimeOperationId {
    return [guid]::NewGuid().ToString()
}

function New-SQLPrimeErrorRecord {
    param(
        [Parameter(Mandatory=$true)][string]$Code,
        [Parameter(Mandatory=$true)][string]$Message,
        [string]$Component = 'app',
        [string]$OperationId = '',
        [System.Exception]$Exception = $null,
        [hashtable]$Data = @{}
    )
    return [pscustomobject]@{
        ok          = $false
        code        = $Code
        message     = $Message
        component   = $Component
        operationId = $OperationId
        exception   = if ($Exception) { $Exception.Message } else { $null }
        data        = $Data
        timestamp   = (Get-Date).ToString('o')
    }
}

function Invoke-SQLPrimeSafe {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$Script,
        [Parameter(Mandatory=$true)][string]$Code,
        [string]$Component = 'app',
        [string]$OperationId = ''
    )
    try {
        $result = & $Script
        return [pscustomobject]@{ ok=$true; code='OK'; data=$result; operationId=$OperationId }
    } catch {
        $err = New-SQLPrimeErrorRecord -Code $Code -Message $_.Exception.Message -Component $Component -OperationId $OperationId -Exception $_.Exception
        try { if (Get-Command Write-SQLPrimeStructuredLog -ErrorAction SilentlyContinue) { Write-SQLPrimeStructuredLog -Level ERROR -Component $Component -OperationId $OperationId -Message $err.message -Data @{ code=$Code } } } catch { }
        return $err
    }
}
