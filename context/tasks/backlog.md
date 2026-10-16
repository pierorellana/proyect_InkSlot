# Backlog ejecutable — P0 y P1

Formato `ID | Entregable | Spec | Verificación`.

| ID | Trabajo | Fuente | Evidencia |
|---|---|---|---|
| T-001 | Crear carpetas app/api/context, dev env, Compose PG | ADR-001 | comandos reproducibles |
| T-002 | Configurar Flutter Web/Provider/GoRouter/tema | UI | tests widget + tokens |
| T-003 | Migrar assets logo D, iconos, ilustraciones y tipografías desde ZIP | DESIGN | paridad capturas |
| T-004 | Animar splash y welcome con fallback reduced motion | UI | golden + interacción |
| T-005 | Modelos/migraciones PG incluyendo exclusion constraint | DATA/RD-09 | integration concurrente |
| T-006 | Auth admin con guard, sesión y rate limiting | AUTH | integration 401/403 |
| T-007 | Jornada semanal, bloques, parámetros y admin Agenda | RD | unit + CRUD |
| T-008 | Motor availability puro con timezone/buffer/horizonte | RD-01..12 | fixture suite |
| T-009 | OAuth Google conectar/desconectar/status + freeBusy | CALENDAR | simuladores fallas |
| T-010 | CRUD solicitudes y clientes, token seguro, renovar/revocar | REQUESTS | 410/hash/rotación |
| T-011 | UI admin crear solicitud/enlace copiar/compartir/listas | ADMIN | screenshot + tests |
| T-012 | Disponibilidad pública, fechas/rueda y deep link | API/UI | unit + E2E + widget + Web build |
| T-013 | Confirm endpoint idempotente transaccional | APPOINTMENTS | test carrera + 409 |
| T-014 | Outbox worker/events/retry/error reconciliation | CALENDAR | no eventos duplicados |
| T-015 | Estado success/pending/conflict/expired/offline/error | UI | matriz de estados |
| T-016 | CRUD acciones cita admin + Calendar update/delete | APPOINTMENTS | audit + sync |
| T-017 | Dashboard incidencias, filtro solicitudes/citas | ADMIN | E2E |
| T-018 | Contract/OpenAPI docs + seguridad + CI + deploy | QUALITY | pipeline verde |
| T-019 | Auditoría de paridad con 38 capturas y accesibilidad | DESIGN | checklist completa |
| T-020 | Piloto: tasa de no agendadas y fallos sincronización | PRODUCT | métricas |

## Definition of Done
Para cada T: spec citada, tests unit/widget/integration pertinentes, errores/loading/empty, secretos fuera del repo, logs con requestId sin PII innecesaria, actualización OpenAPI/ADR si aplica, evidencia visual y commit enfocado. P1 no se implementa antes de estabilizar P0.

## Avance documentado — 2026-10-15

- `T-002`: base Flutter Web 3.47.5 con FVM, Provider, GoRouter, tema y primitivas visuales implementada.
- `T-003`: logo, ilustraciones y tipografías locales importados desde el ZIP aprobado.
- `T-004`: splash y bienvenida públicos implementados con animación 3D, skip intro y reduced motion.
- `T-005`: modelo Prisma inicial, migración PostgreSQL, checks de rango y exclusión GiST implementados; concurrencia transaccional completa queda para confirmación.
- `T-006`: login/me/logout local con Argon2id, cookie HttpOnly, sesión hash y throttling base implementados; guards de rutas admin y CSRF de despliegue quedan pendientes.
- `T-008`: motor puro timezone-aware implementado con jornada, duración, paso, pausas, restricciones, bloqueos, ocupaciones, buffer, aviso, horizonte y fallo cerrado de Calendar; su exposición pública y repositorio Flutter se entregan en T-012.
- `T-007`: configuración admin de zona, paso, buffer, aviso, horizonte, jornadas y CRUD de bloqueos implementada con guard y transacciones; Agenda visual queda pendiente.
- `T-009`: conexión OAuth local de Google Calendar implementada con estado anti-CSRF de un solo uso, refresh token cifrado, selección única del calendario `InkSlot`, status, connect, callback, disconnect y reconnect; provider/service de `freeBusy` y transición persistida a `NEEDS_RECONNECT` implementados, con integración Nest + Prisma local y errores seguros sin tokens ni detalles del proveedor. CRUD de eventos, outbox, retries, incidencias de sincronización y UI Calendar de Flutter quedan pendientes.
- `T-010`: implementados el alcance de clientes por artista, ciclo de vida de solicitudes, tokens hash-only con renovación/revocación, resolución pública segura y E2E con PostgreSQL local para aislamiento, estados HTTP, rotación e idempotencia. La disponibilidad pública queda implementada en T-012; pendiente la confirmación transaccional.
- `T-011`: flujo administrativo Flutter implementado sobre API real: lista paginada con filtros del prototipo, estados loading/empty/error, detalle con referencia de anticipo e historial, renovación/revocación/cierre con confirmación, errores 400/409/401 seguros, enlace efímero sin hashes/tokens en rutas, shell responsive y pruebas widget/router. Verificación: `fvm dart format lib test`, `fvm flutter test`, `fvm flutter analyze`.
- `T-012`: completado el slice de disponibilidad pública: `GET /v1/public/reservations/:token/availability` con validación de rangos, contexto seguro por token, restricciones, jornada, bloqueos, citas y Google Calendar freeBusy; bienvenida pública con datos reales, calendario responsive, estados seguro/loading/empty/expired/booked/offline/Calendar unavailable, rueda curva de horarios con selección en memoria y formateo IANA para Web. Verificación: API 198 unitarias, 36 E2E y build Nest; Flutter 60 pruebas, `fvm flutter analyze` sin issues y `fvm flutter build web` exitoso. T-013 permanece pendiente para ticket/revisión, confirmación e idempotencia.
