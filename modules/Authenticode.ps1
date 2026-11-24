# SQL PRIME - Authenticode verification (Phase 0)

function Test-SQLPrimeAuthenticode {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string[]]$ExpectedPublisherPatterns = @('Microsoft')
    )
    $result = [pscustomobject]@{
        Path = $Path
        Exists = (Test-Path -LiteralPath $Path)
        Supported = $false
        Status = 'Unknown'
        IsTrusted = $false
        Publisher = $null
        Thumbprint = $null
        Message = ''
    }
    if (-not $result.Exists) { $result.Message = 'Archivo no existe'; return $result }

    if (-not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) {
        $result.Message = 'Get-AuthenticodeSignature no disponible en este entorno'
        return $result
    }

    $result.Supported = $true
    try {
        $sig = Get-AuthenticodeSignature -FilePath $Path
        $result.Status = [string]$sig.Status
        $result.IsTrusted = ($sig.Status -eq 'Valid')
        $result.Publisher = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { $null }
        $result.Thumbprint = if ($sig.SignerCertificate) { $sig.SignerCertificate.Thumbprint } else { $null }

        if ($result.IsTrusted -and $ExpectedPublisherPatterns.Count -gt 0) {
            $match = $false
            foreach ($p in $ExpectedPublisherPatterns) {
                if ($result.Publisher -like "*$p*") { $match = $true; break }
            }
            if (-not $match) {
                $result.IsTrusted = $false
                $result.Message = "Firma válida pero publisher no esperado: $($result.Publisher)"
                return $result
            }
        }

        $result.Message = if ($result.IsTrusted) { 'Firma Authenticode válida' } else { "Firma no confiable: $($result.Status)" }
    } catch {
        $result.Status = 'Error'
        $result.IsTrusted = $false
        $result.Message = $_.Exception.Message
    }
    return $result
}
