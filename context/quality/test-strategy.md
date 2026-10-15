# Estrategia de pruebas y pipeline

**NestJS Jest**: unit availability (RD-01..12), requests/token hash expiry, auth, appointment state machine, Google adapter fake; integration Testcontainers PostgreSQL con constraint GiST, transacciones concurrentes y outbox; contrato OpenAPI; e2e Supertest 401/403/409/410/422/503.

**Flutter**: unit ViewModels Provider/Repositories; widget loading/empty/error/scenarios; golden tests con 390×844 y fuentes cargadas; navegación deep link/back, teclado y accesibilidad; integration en browser real, Safari iOS manual para animaciones/correcto touch.

**CI**: format + static analysis (`flutter analyze`, `dart format --output=none --set-exit-if-changed`, `eslint`, `prettier`, `tsc`), tests, migración PG, build Flutter web y Nest, escaneo de secretos y dependencias, despliegue a staging, smoke E2E. `.env.example` sin secrets; env producción separada. Publicar manifest/version de DB y API.

**Observabilidad**: requestId, audit actor, outbox attempt count, Google latency/status, ratio sync pending, pendientes antiguas; no log de credenciales, tokens ni PII innecesaria.
