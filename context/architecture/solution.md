# Arquitectura objetivo

```text
Flutter Web (Provider + GoRouter)
   | HTTPS JSON / cookie admin o token público
NestJS API (controllers → services/use cases → repositories)
   |-- PostgreSQL (source-of-truth, outbox, audit)
   |-- Google Calendar OAuth/freeBusy/events
   `-- Background worker (outbox retries/reconciliation)
```

Workspace únicamente `app/`, `api/`, `context/` en raíz. `context/` incluye este contenido; insumos externos pueden estar en `context/references/` cuando usuario los copie.

**Frontend**: feature-first (`features/auth`, `features/public_booking`, `features/admin_requests`, `features/admin_appointments`, `features/availability`, `features/calendar_connection`, `core/theme`, `core/network`, `core/router`, `shared/widgets`). Provider ChangeNotifier, estados sellados/modelados, repositorios inyectados con Provider. DTOs aislados de entidades UI; testing Widget/Golden.

**Backend implementado**: módulos Nest `auth`, `requests`, `availability`, `appointments`, `calendar`, `sync`, `dashboard`, `database` y `health`; los alcances de clientes, auditoría y configuración viven en sus servicios y modelos actuales. DTO validation con class-validator/class-transformer y ValidationPipe whitelist/forbidNonWhitelisted. Persistencia con Prisma y migraciones SQL explícitas para la constraint de exclusión. OpenAPI versionado, CI, deploy y backup/restore permanecen como trabajo de calidad pendiente.

**Transversal**: logs HTTP estructurados con `X-Request-Id`, health checks, rate limit global y por ruta, CORS/validación de origen, headers de seguridad, secrets por env, migraciones y worker in-process de outbox. OpenTelemetry, CI, deploy y backup/restore permanecen pendientes.

**Criterio de seguridad**: fallo de Calendar `freeBusy` ⇒ bloquear confirmación; fallo al escribir evento después del commit ⇒ cita confirmada internamente y sync pendiente con alerta admin.
