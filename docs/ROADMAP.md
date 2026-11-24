# SQL PRIME — Roadmap de evolución

> Estado: Fase 0 iniciada en rama `arena/50a9bbe3-sql-prime`.

## Fase 0 — Fundamentos (en progreso)
- [x] Estructura base `modules/`, `catalog/`, `config/`, `docs/`, `logs/`
- [x] Configuración versionada (`config/app.config.json`, `schemaVersion`)
- [x] Logging estructurado JSONL con rotación (`modules/Logging.ps1`)
- [x] Verificación de integridad SHA-256 para descargas (`modules/Integrity.ps1`)
- [x] Catálogo base de instaladores con tamaños/hashes (`catalog/catalog.json`)
- [x] Tests Pester iniciales (Config/Integrity/ErrorHandling/Catalog/Authenticode) en `tests/`
- [ ] Separación completa UI/Core del script monolítico (en progreso: Config/Logging/Integrity/ErrorHandling/Authenticode/Catalog/Inventory extraídos)
- [x] Verificación Authenticode (módulo + warning/confirmación; política estricta configurable `security.verifyAuthenticode`)

- [x] Manejo de errores estandarizado + `operationId` en descargas (`modules/ErrorHandling.ps1`)
- [x] Script para poblar SHA256 desde archivos locales (`scripts/Update-CatalogHashes.ps1`)

## Fase 1 — UX/UI premium
- [ ] Design system (tokens, iconos SVG, estados)
- [ ] Dashboard con KPIs y semáforo
- [ ] Centro de descargas con %, velocidad, ETA, pausa/reanuda por archivo
- [ ] Wizard Diagnosticar → Respaldar → Aplicar → Verificar
- [ ] Accesibilidad e i18n ES/EN

## Fase 2 — Seguridad y SQL avanzado
- [ ] Mínimo privilegio/UAC por acción
- [ ] Verificación Authenticode de instaladores
- [ ] Playbooks de reparación por síntoma
- [ ] Inventario multi-instancia y reportes HTML/PDF antes/después
- [ ] Backup/rollback y auditoría

## Fase 3 — Distribución producto
- [ ] Empaquetado MSIX/MSI firmado
- [ ] Auto-update con manifiesto firmado y rollback
- [ ] CI/CD Windows (lint, Pester, firma, checksums)
- [ ] Telemetría opt-in

## Fase 4 — Web/API HTTPS con ECC
- [x] Scaffold inicial **C#/.NET 8** (`src/SQLPrime.Core`, `src/SQLPrime.Api`)
- [x] ASP.NET Core + Kestrel con **TLS 1.3** (config base en `Program.cs`)
- [x] Plantilla de certificado **ECDSA P-256/P-384** (ECC), HSTS, CSP (ver `docs/PHASE_3_TLS_ECC.md`)
- [ ] Auth OIDC/MFA, RBAC, auditoría, rate limiting
- [ ] Despliegue producción con secretos en vault/HSM

## Stack recomendado
- **Principal**: C#/.NET 8, WinUI 3 (desktop), ASP.NET Core (web/API), MSIX.
- **Alternativas**: Tauri+Rust+React; Electron+TS; Python+PySide6.
- **Motivo**: mejor integración Windows/admin, seguridad, rendimiento, mantenibilidad.
