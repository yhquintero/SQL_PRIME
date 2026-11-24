#requires -Version 5.1
<#
.SYNOPSIS
Generates a self-signed ECDSA P-256 certificate for SQL PRIME local/dev HTTPS.
.NOTES
For development only. Production must use CA/ACME/vault-issued certs with rotation.
#>
[CmdletBinding()]
param(
    [string]$DnsName = 'localhost',
    [string]$OutDir = (Join-Path $PSScriptRoot '..\certs'),
    [string]$CertName = 'sqlprime-dev-ecdsa-p256',
    [securestring]$PfxPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $PfxPassword) {
    $PfxPassword = ConvertTo-SecureString 'ChangeMe-DevOnly!' -AsPlainText -Force
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$cert = New-SelfSignedCertificate `
    -Subject "CN=$DnsName" `
    -DnsName $DnsName `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -KeyAlgorithm ECDSA_nistP256 `
    -KeyExportPolicy Exportable `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(1) `
    -FriendlyName $CertName

$pfxPath = Join-Path $OutDir "$CertName.pfx"
$cerPath = Join-Path $OutDir "$CertName.cer"
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $PfxPassword | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

Write-Host "Generated ECDSA P-256 dev cert:"
Write-Host "  PFX: $pfxPath"
Write-Host "  CER: $cerPath"
Write-Host "Configure SQLPrime.Api appsettings Kestrel:Certificates:Default accordingly."
