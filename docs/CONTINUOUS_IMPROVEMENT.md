# SQL PRIME — Mejora continua (Top 1)

> Documento vivo. Cada iteración debe dejar una evidencia verificable: test, captura, log o reporte generado.

## Estado actual de la iteración P0/P1

- [x] Design system centralizado (`config/design-system.json`, `modules/DesignSystem.ps1`) con tokens para UI y CSS.
- [x] Telemetría local con sparklines (`scripts/New-SQLPrimeTelemetryDashboard.ps1`).
- [x] Dry-run con diff y rollback (`New-SQLPrimeDryRunPreview`, activo al encender SIMULACIÓN).
- [x] Tests de integración con proveedor de URL simulado y estados `.part`.

## Backlog de la iteración anterior (P1/P2)

| # | Aspecto | Estado |
|---|---|---|
| 1 | Centro de descargas Pro: ETA/velocidad/pausa por archivo/cola persistente | Parcial |
| 2 | Wizard WPF de 4 pasos integrado | Scaffold |
| 3 | i18n + accesibilidad reales en UI | Scaffold |
| 4 | Reporte ejecutivo antes/después + PDF | HTML listo, falta PDF |
| 5 | Hashes SHA-256 oficiales de 3 instaladores x86 | 3 pendientes |
| 6 | Design system / paleta centralizada | Implementado |
| 7 | Telemetría local + sparklines | Implementado |
| 8 | Modo dry-run con diff planeado y rollback | Implementado |

## Nuevos aspectos para seguir superándose

### Producto y UX

| Aspecto | Qué eleva | Idea concreta |
|---|---|---|
| Microinteracciones | Percepción de calidad | Transiciones suaves al cambiar de pestaña, hover con glow sutil, feedback de botón con ripple |
| Onboarding guiado | Adopción | Primer arranque con checklist: detectar → inventariar → descargar → reparar → verificar |
| Command palette | Potencia para usuarios avanzados | `Ctrl+K` para ejecutar acciones (refrescar, descargar, exportar) con búsqueda |
| Modo compacto | Distintos perfiles de pantalla | Conmutador “compacto / confort” que ajuste densidad y tipografía |
| Multi-instancia | Escalabilidad real | Selector de instancia en todas las operaciones con validación de permisos |
| Explicabilidad | Confianza | Cada acción crítica muestra “por qué es necesaria”, “qué cambia” y “cómo revertir” |
| Notificaciones no intrusivas | Menos fatiga | Centro de avisos dentro de la app en vez de diálogos modales |
| Tutoriales contextuales | Curva de aprendizaje | Tooltips con evidencia (KB/enlace oficial) junto a cada SP/CU |

### Ingeniería y calidad

| Aspecto | Qué eleva | Idea concreta |
|---|---|---|
| Arquitectura MVVM real | Mantenibilidad | Portar la UI WPF a .NET 8 con ViewModels, comandos y servicios inyectados |
| CLI JSON output | Automatización | `--format json` para todas las operaciones, con esquema versionado |
| Paridad PS 5.1 / PS 7 | Compatibilidad | Matriz de tests ejecutada en ambas versiones en CI |
| Property-based tests | Robustez | Generar nombres de instaladores aleatorios y validar el parser de inventario |
| Fault injection | Resiliencia | Simular timeouts, HTTP 200 en vez de 206 y hashes incorrectos en tests |
| Benchmarks de rendimiento | Velocidad | Medir escaneo de inventario y cálculo de hash en distintos tamaños |
|Perfilado de UI | Fluidez | Capturar traces de WPF para detectar bloqueos del dispatcher |
| SBOM | Supply chain | Generar CycloneDX del proyecto y de dependencias .NET en cada release |

### Seguridad y confianza

| Aspecto | Qué eleva | Idea concreta |
|---|---|---|
| Rollback atómico | Seguridad operativa | Antes de cada cambio, guardar estado y permitir revertir con un clic |
| Firma de artefactos | Integridad | Firmar MSIX y reportes exportados con certificado de organización |
| Certificate pinning | Defensa en profundidad | Fijar huellas de certificados de endpoints oficiales de Microsoft |
| Almacenamiento seguro de secretos | Cumplimiento | Credenciales solo en DPAPI/Windows Credential Manager, nunca en JSON |
| Auditoría inmutable | Trazabilidad | Encadenar eventos JSONL con hash del evento anterior |
| Tipado de permisos | Menos errores | Verificar permisos antes de habilitar botones críticos |
| Modo air-gapped | Entornos aislados | Paquete offline con catálogo, hashes y scripts verificados |
| Política de hashes | Calidad del catálogo | Solo aceptar SHA256 de fuente oficial con evidencia y fecha de verificación |

### Datos, reportes y observabilidad

| Aspecto | Qué eleva | Idea concreta |
|---|---|---|
| Reporte PDF ejecutivo | Entregabilidad | Exportar el HTML actual a PDF con resumen, evidencia y firma |
| Antes/después con métricas | Demo profesional | Servicios, versión, build, hashes y tiempo de operación comparados |
| Dashboard histórico | Tendencias | Sparklines ya implementados + filtros por componente/nivel |
| OpenTelemetry | Observabilidad estándar | Exportar trazas/métricas del API .NET a OTLP local |
| Salud del catálogo | Calidad de datos | Regla: ningún instalador sin URL o hash quede “silenciosamente” pendiente |
| Alertas de regresión | Prevención | Si la tasa de ERROR sube, avisar en el dashboard |
| Exportación CSV/JSON | Interoperabilidad | Que todos los reportes tengan versión estructurable además de HTML |
| Colección de métricas de uso (opt-in) | Producto guiado por datos | Telemetría local, anónima y desactivable, con consentimiento explícito |

### Distribución y ciclo de vida

| Aspecto | Qué eleva | Idea concreta |
|---|---|---|
| MSIX firmado + auto-update | Profesionalismo | Actualización silenciosa con verificación de firma y rollback |
| Release notes automáticas | Comunicación | Generar changelog desde commits convencionales |
| Versionado semántico | Claridad | `v1.x.y` con política de compatibilidad documentada |
| Guía de migración | Adopción | Instrucciones claras entre versiones y scripts de conversión de config |
| Pipelines renamed | Señal de calidad | Badges de CI, cobertura y seguridad en README |
| Capturas frescas | Primera impresión | Regenerar `docs/assets/sql-prime-dashboard.png` tras cada cambio visual |
| Reproducibilidad | Confianza | Build determinista con lockfiles y contenedor de desarrollo |
| Política de soporte | Madurez | Tabla de versiones de SQL Server soportadas y fecha de fin de soporte |

## Regla de oro para cada iteración

1. Cambiar **una** dimensión notable.
2. Añadir o actualizar una **prueba**.
3. Generar una **evidencia** (reporte/log/captura).
4. Actualizar **README + roadmap + este documento**.
5. Publicar y verificar en la web de GitHub.
