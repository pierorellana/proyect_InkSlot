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

**Backend**: módulos Nest `auth`, `clients`, `requests`, `availability`, `appointments`, `calendar`, `sync`, `audit`, `settings`, `health`. DTO validation con class-validator/class-transformer y ValidationPipe whitelist/forbidNonWhitelisted. Swagger OpenAPI generado y versionado. Persistencia con Prisma o TypeORM **por decidir**; SQL migration explícita para constraint de exclusión.

**Transversal**: logs estructurados con correlationId, OpenTelemetry opcional, health checks, rate limit, secrets por env, CI, migraciones, backup/restore, scheduler worker separado si despliegue lo exige.

**Criterio de seguridad**: fallo de Calendar `freeBusy` ⇒ bloquear confirmación; fallo al escribir evento después del commit ⇒ cita confirmada internamente y sync pendiente con alerta admin.
