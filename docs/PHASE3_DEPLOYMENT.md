# Phase 3 Deployment / Hardening Checklist

> Status: scaffold/checklist. Production deployment requires real infra validation.

## TLS / ECC
- [ ] Use CA/ACME/vault-issued ECDSA P-256 or P-384 certificate (no self-signed in prod).
- [ ] Enable TLS 1.3 preferred, TLS 1.2 fallback only if required.
- [ ] Disable TLS 1.0/1.1, weak ciphers, RSA-only fallback where possible.
- [ ] Automate cert rotation and alert on expiry.
- [ ] Validate with `testssl.sh` and SSL Labs.

## API security
- [ ] OIDC/OAuth2 authentication + MFA for admin actions.
- [ ] RBAC authorization (least privilege).
- [ ] Rate limiting / brute-force protection.
- [ ] Audit log for security-sensitive actions.
- [ ] Secrets in vault/KMS, never in repo.
- [ ] CORS restricted to known origins.

## Network / runtime
- [ ] Reverse proxy/WAF in front of Kestrel.
- [ ] HSTS, CSP, X-Content-Type-Options, Referrer-Policy, frame protection.
- [ ] Centralized logs/metrics/traces with alerting.
- [ ] Backup/restore tested.
- [ ] Incident response runbook.

## Dev cert helper
Use `scripts/New-SQLPrimeEccCert.ps1` for local development only.
