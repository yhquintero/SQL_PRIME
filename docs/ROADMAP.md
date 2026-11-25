# SQL PRIME — Roadmap de evolución

> Estado: avances incrementales en rama `arena/50a9bbe3-sql-prime` (PR #13 abierto).

## Fase 0 — Fundamentos (en progreso)
- [x] Estructura base `modules/`, `catalog/`, `config/`, `docs/`, `logs/`
- [x] Configuración versionada (`config/app.config.json`, `schemaVersion`)
- [x] Logging estructurado JSONL con rotación (`modules/Logging.ps1`)
- [x] Verificación de integridad SHA-256 para descargas (`modules/Integrity.ps1`)
- [x] Catálogo base de instaladores (`catalog/catalog.json`) — 3 SHA256 verificados, 3 x86 pendientes con hash oficial verificado
- [x] Tests Pester ampliados: Config/Integrity/ErrorHandling/Catalog/Authenticode/Inventory/ValidateCatalog/Detection/Services/Download/Wizard/I18n
- [x] Módulos extraídos: Config/Logging/Integrity/ErrorHandling/Authenticode/Catalog/Inventory/Services/Detection/Download/Wizard/I18n
- [x] `Start-InstallerDownloads` usa `Get-SQLPrimeDownloadTargets` (fallback legacy)
- [x] Verificación Authenticode (módulo + warning/confirmación; política estricta configurable `security.verifyAuthenticode`)
- [x] Manejo de errores estandarizado + `operationId` en descargas (`modules/ErrorHandling.ps1`)
- [x] Script para poblar SHA256 desde archivos locales (`scripts/Update-CatalogHashes.ps1`)
- [x] CI Windows: Pester + `Validate-Catalog.ps1` + .NET restore/build/test (`.github/workflows/ci-windows.yml`)
- [ ] Separación completa UI/Core del script monolítico (pendiente: Repair completo, UI/Theme, flujos UI-coupled)
- [ ] Tests adicionales: mocks de red/descarga, integración `.part`, casos Authenticode en flujo real

## Fase 1 — Estabilizar producto actual
- [x] Wizard state machine base: `modules/Wizard.ps1` + tests (falta integración UI WPF)
- [ ] Centro de descargas completo: ETA/velocidad/pause-per-file/cola persistente (base: progreso + reanudación `.part`)
- [x] Reporte HTML base: `scripts/New-SQLPrimeReport.ps1` (falta antes/después + PDF)
- [x] Barras de progreso futuristas: degradado/glow en UI WPF y modal, KPIs con barras animadas en reportes (`New-SQLPrimeReport.ps1` y `Export-SQLPrimeReport`)
- [x] i18n scaffold: `modules/I18n.ps1`, `config/i18n/es.json`, `config/i18n/en.json` (falta integración UI)
- [ ] Accesibilidad completa (teclado, contraste, lector de pantalla)

## Fase 2 — Migración técnica (.NET 8)
- [x] Solución scaffold: `SQLPrime.sln`, `Directory.Build.props`
- [x] Proyectos: `src/SQLPrime.Core`, `src/SQLPrime.Api`, `src/SQLPrime.WindowsAgent` (scaffold), `src/SQLPrime.Desktop` (scaffold), `src/SQLPrime.Core.Tests`
- [x] Core C# inicial: `CatalogLoader`, `InstallerCatalog`, `HashVerifier` + tests xUnit
- [ ] Portar lógica completa con paridad funcional (detección, descarga, reparación, reportes)
- [ ] MVVM + DI + async/await/cancelación en Desktop
- [ ] Empaquetado MSIX/MSI firmado

## Fase 3 — Web/HTTPS con ECC
- [x] API scaffold: `src/SQLPrime.Api` (Kestrel, TLS 1.3/1.2, HSTS, headers seguridad, rate limiting fijo, audit log básico)
- [x] Docs: `docs/PHASE_3_TLS_ECC.md`, `docs/PHASE3_DEPLOYMENT.md`
- [x] Script dev cert ECDSA P-256: `scripts/New-SQLPrimeEccCert.ps1` (solo dev)
- [ ] Certificado ECDSA P-256/P-384 real + rotación (CA/ACME/vault)
- [ ] OIDC + MFA + RBAC
- [ ] Auditoría persistente, rate limiting distribuido, WAF/reverse proxy
- [ ] Validación seguridad: `testssl.sh`/SSL Labs, hardening producción

## Pendientes críticos
- Poblar 3 hashes `sha256: null` x86 en `catalog/catalog.json` solo con hashes oficiales verificados.
- Completar integración UI real (wizard, i18n, accesibilidad, reportes antes/después).
- Portar lógica completa a .NET 8 con pruebas y empaquetado firmado.
- Implementar seguridad/infra real de producción para API HTTPS.
