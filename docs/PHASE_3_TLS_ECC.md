# Fase 3 — HTTPS/TLS 1.3 con ECC (scaffold)

## Objetivo
Exponer un componente web/API de SQL PRIME con seguridad moderna:
- **TLS 1.3** (preferido) / TLS 1.2 mínimo de compatibilidad controlada.
- Certificado **ECDSA P-256 (prime256v1)** o **P-384**.
- Key exchange ECDHE (manejado por TLS 1.3).
- HSTS + headers de seguridad.

## Estado actual
- Scaffold creado en `src/SQLPrime.Api` (.NET 8, Kestrel).
- `Program.cs` fuerza `Tls13 | Tls12` y agrega headers básicos.
- `appsettings.json` define endpoint HTTPS con certificado PFX (placeholder).

## Generar certificado ECDSA para desarrollo (ejemplo)
```bash
# P-256 ECDSA self-signed (dev only)
openssl ecparam -name prime256v1 -genkey -noout -out sqlprime-ec.key
openssl req -new -x509 -key sqlprime-ec.key -out sqlprime-ec.crt -days 365 -subj "/CN=sqlprime.local"
openssl pkcs12 -export -out sqlprime-ecdsa.pfx -inkey sqlprime-ec.key -in sqlprime-ec.crt
```

> En producción: usar CA confiable (ACME/Let's Encrypt o CA corporativa), almacenar llave en vault/HSM/DPAPI, rotación automática.

## Checklist de hardening
- [ ] TLS 1.3 habilitado; TLS 1.0/1.1 deshabilitado.
- [ ] Certificado ECDSA P-256/P-384 válido y cadena completa.
- [ ] HSTS, CSP, X-Content-Type-Options, Referrer-Policy.
- [ ] OIDC/MFA, RBAC, rate limiting.
- [ ] Secretos fuera del repo (`CHANGE_ME...` solo placeholder).
- [ ] Pruebas: `testssl.sh`, SSL Labs/internal scan.
