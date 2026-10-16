# Plan de implementación: acciones administrativas de citas y Calendar update/delete

> **Para agentes de implementación:** ejecutar una tarea a la vez, mantener las casillas actualizadas y cerrar cada tarea con un commit Conventional Commit enfocado.

**Objetivo:** entregar T-016 como un slice vertical API NestJS que permita consultar citas del artista, reprogramarlas, cancelarlas, completarlas y marcarlas como no-show, manteniendo PostgreSQL como fuente de verdad y sincronizando update/delete con Google Calendar mediante el outbox de T-014.

**Arquitectura:** extender el contrato Calendar existente y el worker local de T-014 para tres operaciones (`create`, `update`, `delete`). Añadir el módulo administrativo de citas dentro de `AppointmentsModule`, con DTOs estrictos, cursor por `startAt/id`, servicio de disponibilidad para reprogramación y transacciones PostgreSQL `Serializable` con control optimista por `Appointment.version`. No se crea otro worker, cola, servicio externo ni migración.

**Stack:** NestJS 11, TypeScript, Prisma 6.19, PostgreSQL local, `googleapis`, Jest/Supertest y el `AvailabilityEngine` existente. Flutter no forma parte de este slice.

## Restricciones globales

- Mantener solo `app`, `api` y `context` como carpetas principales del workspace.
- Usar PostgreSQL local; no añadir Docker, Compose, Redis ni una cola externa.
- No añadir migraciones Prisma en T-016. Reutilizar `Appointment.version`, la exclusión SQL `appointments_no_overlap`, `CalendarEvent`, `OutboxEvent`, `SyncIssue` y `AuditLog`.
- Mantener `AppointmentStatus.CONFIRMED` al reprogramar; no crear `RESCHEDULED`.
- Todas las acciones administrativas deben filtrar por `artistId` de la sesión autenticada y no revelar citas de otro artista.
- No devolver tokens, hashes, credenciales, mensajes crudos de Google, PII innecesaria ni datos de pago en respuestas o descripciones de Calendar.
- Cancelar debe confirmar primero el estado interno y encolar el delete aunque todavía no exista `CalendarEvent`.
- Reprogramar debe verificar reglas internas y `freeBusy` antes de escribir; un Calendar no verificable responde `503 CALENDAR_UNAVAILABLE` y no cambia la cita.
- Las operaciones de sync son at-least-once y deben conservar el ID determinista `sha256(inkslot:appointment:<appointmentId>)`.
- El update externo usa el mismo `calendarId/eventId`; un evento ausente se recrea con el mismo ID. El delete 404 es éxito.
- Los errores públicos conservan el envelope `{ error: { code, message } }` existente.
- Consultar Context7 antes de modificar llamadas de `googleapis`, transacciones Prisma o composición NestJS. Ya se verificaron las APIs relevantes para este plan: `/googleapis/google-api-nodejs-client`, `/prisma/web` y `/nestjs/docs.nestjs.com`.
- Cada tarea termina con pruebas enfocadas, `npm run build`, `git diff --check` y un commit pequeño. No hacer push remoto durante la implementación local.

## Mapa de archivos

Crear:

- `api/src/appointments/admin-appointments.dto.ts` — query/body DTOs con validación estricta.
- `api/src/appointments/admin-appointments.controller.ts` — endpoints administrativos.
- `api/src/appointments/admin-appointments.service.ts` — lectura, acciones, ownership, auditoría y outbox.
- `api/src/appointments/appointment-cursor.ts` — cursor opaco validado para `startAt/id`.
- `api/src/appointments/admin-appointments.service.spec.ts` — unitarias de lectura y ciclo de vida.
- `api/src/availability/appointment-availability.service.ts` — preflight reusable para reprogramación.
- `api/src/availability/appointment-availability.service.spec.ts` — reglas y exclusión de la cita actual.
- `api/test/admin-appointments.e2e-spec.ts` — flujo PostgreSQL con fake Calendar.

Modificar:

- `api/src/calendar/calendar.provider.ts` — contratos `updateEvent`/`deleteEvent` y error de evento ausente.
- `api/src/calendar/google-calendar.provider.ts` — llamadas `events.update`/`events.delete` y mapeo seguro.
- `api/src/calendar/calendar.service.ts` — boundary seguro para update/delete.
- `api/src/calendar/calendar.module.ts` — mantener exportación del boundary para sync.
- `api/src/calendar/*.spec.ts`, `api/test/calendar.e2e-spec.ts`, `api/test/calendar-outbox.e2e-spec.ts` — fakes y regresiones del contrato.
- `api/src/sync/sync.constants.ts` — operaciones y resultados discriminados.
- `api/src/sync/calendar-sync.service.ts` — dispatch create/update/delete e idempotencia.
- `api/src/sync/sync-issues.service.ts` — finalización por operación e incidencias scoped.
- `api/src/sync/outbox-worker.service.ts` y `api/src/sync/sync.module.ts` — conectar tipos ampliados sin cambiar claim/lease.
- `api/src/sync/*spec.ts` — pruebas de operaciones y finalización.
- `api/src/availability/availability.module.ts` — exportar el preflight de citas.
- `api/src/appointments/appointments.module.ts` — importar Availability/Auth/Calendar/Prisma y registrar controller/providers.
- `context/design/2026-10-16-inkslot-appointments-actions-design.md` — estado aprobado.
- `context/tasks/backlog.md` — evidencia final de T-016.

---

## Tarea 1: ampliar Calendar para update/delete idempotentes

**Commit:** `feat(api): add calendar event update and delete`

**Archivos:** `api/src/calendar/calendar.provider.ts`, `api/src/calendar/google-calendar.provider.ts`, `api/src/calendar/calendar.service.ts`, tests de Calendar y fakes.

**Contrato:**

```ts
export type CalendarProviderErrorCode =
  | 'CALENDAR_NOT_CONFIGURED'
  | 'CALENDAR_UNAVAILABLE'
  | 'CALENDAR_REAUTH_REQUIRED'
  | 'CALENDAR_EVENT_EXISTS'
  | 'CALENDAR_EVENT_NOT_FOUND'
  | 'OAUTH_ACCESS_DENIED';

export interface CalendarProvider {
  // contratos existentes...
  updateEvent(input: CalendarEventInput): Promise<CalendarEventResult>;
  deleteEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<void>;
}
```

- [ ] Escribir primero pruebas para `events.update` con el mismo `calendarId/eventId`, `sendUpdates: 'none'`, payload completo, fechas ISO UTC, zona IANA y retorno de `etag`.
- [ ] Implementar `GoogleCalendarProvider.updateEvent`; mapear 404 a `CALENDAR_EVENT_NOT_FOUND`, 401/403 a `CALENDAR_REAUTH_REQUIRED`, 409 a `CALENDAR_EVENT_EXISTS` y el resto a `CALENDAR_UNAVAILABLE`, sin propagar texto del proveedor.
- [ ] Implementar `deleteEvent` con `events.delete`; tratar 404 como éxito idempotente y mapear 401/403 y fallos transitorios con los errores seguros existentes.
- [ ] Añadir `CalendarService.updateEvent(artistId, input)` y `deleteEvent(artistId, eventId)`, reutilizando `loadEventConnection`, descifrado solo en memoria y `markNeedsReconnect` para 401/403.
- [ ] Actualizar todos los `CalendarProvider` fakes con `rg -n "CalendarProvider|as jest.Mocked<CalendarProvider>" api/src api/test`; conservar intactos OAuth, `freeBusy`, status y disconnect.
- [ ] Ejecutar tests de provider/service, tests Calendar existentes, build y diff check; crear el commit enfocado.

## Tarea 2: extender el sync a create/update/delete

**Commit:** `feat(api): sync calendar appointment updates and deletes`

**Archivos:** `api/src/sync/sync.constants.ts`, `calendar-sync.service.ts`, `sync-issues.service.ts`, `outbox-worker.service.ts`, `sync.module.ts` y specs.

- [ ] Añadir `OUTBOX_UPDATE_EVENT` y `OUTBOX_DELETE_EVENT`; parsear estrictamente el mismo payload de dos claves `{ appointmentId, operation }`, aceptando solo UUID y operación válida.
- [ ] Convertir el resultado interno a unión discriminada:

  ```ts
  type CalendarSyncSuccess =
    | { operation: 'create' | 'update'; appointmentId: string; calendarId: string; externalEventId: string; etag: string | null }
    | { operation: 'create'; effect: 'noop'; appointmentId: string }
    | { operation: 'delete'; effect: 'deleted'; appointmentId: string };
  ```

- [ ] Mantener create idempotente: leer la cita actual antes de llamar a Google; si ya no está `CONFIRMED`, devolver `create/noop` sin crear CalendarEvent; si existe CalendarEvent local, finalizar como aplicado; si hay conflicto de ID, recuperar por `getEvent`.
- [ ] Implementar update con la proyección completa actual (`InkSlot — <client name>`, `Reserva InkSlot · <duration> min`, fechas y timezone). Usar el ID determinista, llamar update y, ante `CALENDAR_EVENT_NOT_FOUND`, crear el mismo evento con el mismo ID; ante conflicto de creación, recuperar con `getEvent` y aceptar solo un evento encontrado.
- [ ] Implementar delete cargando la cita para obtener `artistId`, calcular el ID determinista, llamar al boundary de Calendar y devolver éxito también cuando Google informa 404. No depender de que exista `CalendarEvent` local.
- [ ] Cambiar `SyncIssuesService` para que finalice según el `event.type`: update hace upsert de `CalendarEvent` y marca la cita `SYNCED`; delete elimina `CalendarEvent` y marca `SYNCED`; create/no-op completa solo el outbox y no marca `SYNCED`. Resolver y crear incidencias por operación, no asumir siempre create.
- [ ] Hacer que retry/listado de incidencias encuentre el outbox correspondiente por `appointmentId + operation`, manteniendo el orden proyectado de `createdAt` desde `Appointment` porque `SyncIssue` no tiene columna propia.
- [ ] Mantener sin cambios el claim/lease y el backoff de T-014; añadir pruebas unitarias para payloads, recovery, evento ausente, delete sin fila local, no-op cancelado, errores 401/403, retry y carreras idempotentes.
- [ ] Ejecutar el subconjunto de sync/outbox, build y diff check; crear el commit.

## Tarea 3: añadir listado y detalle administrativo de citas

**Commit:** `feat(api): expose admin appointment queries`

**Archivos:** DTO/controller/service/cursor nuevos, `appointments.module.ts` y spec unitaria.

- [ ] Crear DTOs:
  - `ListAdminAppointmentsDto`: `status` opcional en `confirmed|completed|cancelled|no_show` y `cursor` opaco máximo 256.
  - DTOs de acciones con `version` entero positivo.
  - DTO de reprogramación con `startAt` obligatorio, regex UTC con milisegundos y sin `endAt` aceptado.
- [ ] Implementar cursor base64url validado con `{ startAt: ISO, id: UUID }`; listar máximo 20 + 1, orden `startAt ASC, id ASC`, filtro opcional de estado y `artistId` obligatorio.
- [ ] Implementar `GET /v1/admin/appointments` y `GET /v1/admin/appointments/:id` bajo `AdminSessionGuard`. Devolver en listado solo id/status/syncStatus/startAt/endAt/version/client.name/durationMinutes.
- [ ] En detalle, devolver únicamente campos administrativos permitidos: cliente (nombre y contacto ya existente), duración, intervalo, status/syncStatus/version, CalendarEvent activo sin tokens y auditoría `ADMIN` ascendente con action/timestamp/changes sanitizados. No incluir payment reference, refresh token, hashes ni mensajes crudos.
- [ ] Mapear ownership inexistente/ajeno a `404 NOT_FOUND`; validar UUID en el servicio si Param no se transforma; mantener errores seguros.
- [ ] Registrar controller/service en `AppointmentsModule`, que importará `AuthModule` y `PrismaModule` mediante la composición actual de la aplicación.
- [ ] Añadir unitarias para paginación, filtros, orden, campos de respuesta y aislamiento; ejecutar tests y commit.

## Tarea 4: encapsular preflight de disponibilidad para reprogramación

**Commit:** `feat(api): validate appointment rescheduling availability`

**Archivos:** `api/src/availability/appointment-availability.service.ts`, su spec y `availability.module.ts`.

- [ ] Crear un servicio de preflight que reciba `artistId`, `appointmentId`, intervalo candidato, duración y restricciones persistidas de `BookingRequest`.
- [ ] Cargar configuración de estudio, jornadas y bloqueos; convertir `TIME` a `HH:mm` como hace el servicio público; consultar citas del artista en estados `CONFIRMED`, `COMPLETED`, `NO_SHOW`, excluyendo `appointmentId`.
- [ ] Consultar `CalendarService.queryBusy` para el intervalo del día local candidato y propagar una señal tipada de Calendar no verificable; no continuar a la escritura si falla.
- [ ] Ejecutar `AvailabilityEngine.calculate` con notice, horizon, buffer, restrictions e intervalos externos; verificar que existe exactamente el slot candidato (`startAt/endAt`). Un solapamiento interno, externo, bloqueo, jornada, restricción o límite temporal produce `409 SLOT_UNAVAILABLE`.
- [ ] No inferir la identidad de un busy externo: si se solapa, bloquear incluso si coincide con el evento actual. El intervalo interno de la cita actual sí se excluye.
- [ ] Probar timezone IANA, duración/end calculado, exclusión propia, conflictos internos, conflictos externos, jornada, restricciones, bloqueos, notice/horizon y Calendar unavailable. Exportar el servicio desde `AvailabilityModule`.

## Tarea 5: implementar reprogramación transaccional y acciones de estado

**Commit:** `feat(api): add admin appointment lifecycle actions`

**Archivos:** `api/src/appointments/admin-appointments.service.ts`, controller/dto, module y specs.

- [ ] Implementar `PATCH /v1/admin/appointments/:id/reschedule` calculando `endAt = startAt + BookingRequest.durationMinutes`; ejecutar el preflight antes de la transacción de escritura y, dentro de la transacción, volver a leer/lockear la cita por `id + artistId`.
- [ ] Usar transacción `Serializable` con hasta tres reintentos para `P2034`, `40001` y `40P01`; convertir la exclusión SQL `23P01` a `409 SLOT_UNAVAILABLE` y otros fallos a `503 SERVICE_UNAVAILABLE`.
- [ ] En la transacción verificar ownership, estado y versión; para un intervalo exactamente igual devolver la cita actual sin incrementar versión, auditoría ni outbox. Para un cambio válido actualizar intervalo, incrementar versión, mantener `CONFIRMED`, poner `syncStatus = PENDING`, crear un `AuditLog` sin PII y crear un único outbox `appointment.calendar.update` con `{ appointmentId, operation: 'update' }`.
- [ ] Implementar `POST /cancel`: desde `CONFIRMED`, actualizar `CANCELLED`, incrementar versión, auditar y encolar `appointment.calendar.delete` aun sin `CalendarEvent`; no llamar Google dentro de la transacción.
- [ ] Implementar `POST /complete` y `/no-show`: desde `CONFIRMED`, cambiar al estado destino, incrementar versión y auditar; no crear outbox Calendar.
- [ ] Aplicar idempotencia de acciones: repetir la misma acción sobre el estado destino devuelve la representación actual sin nuevo audit/outbox; acción sobre otro estado terminal devuelve `409 APPOINTMENT_STATE_CONFLICT`; una versión obsoleta en una acción que requiere mutación devuelve `409 APPOINTMENT_VERSION_CONFLICT`.
- [ ] Releer la representación actual después del commit para devolver syncStatus/version/evento/auditoría coherentes; mantener la eliminación Calendar eventual.
- [ ] Añadir unitarias de transiciones válidas/inválidas, ownership, version conflict, no-op, auditoría, payload exacto, reintentos y concurrencia; ejecutar tests y commit.

## Tarea 6: cerrar E2E PostgreSQL, regresiones y evidencia SDD

**Commit:** `test(api): verify admin appointment lifecycle and calendar projection`

**Archivos:** `api/test/admin-appointments.e2e-spec.ts`, `api/test/calendar-outbox.e2e-spec.ts`, fakes/fixtures necesarios y `context/tasks/backlog.md`.

- [ ] Crear fixtures aislados para dos artistas, solicitudes con duración/restricciones, citas confirmadas y conexiones Calendar fake; reutilizar el patrón de login/cookies y cleanup existente.
- [ ] Verificar HTTP: 401 sin sesión, 404 cross-artist, listado paginado/filtrado, detalle seguro, DTO desconocido/UTC inválido, errores de estado/version/slot/Calendar.
- [ ] Verificar persistencia: reprogramación deja una cita, una versión nueva, una auditoría y un outbox update; cancelación es inmediata y genera un único delete; complete/no-show no generan Calendar outbox; repetición no duplica.
- [ ] Verificar sync: update conserva el mismo ID, evento ausente se recrea con el mismo ID, delete 404 es éxito, Calendar 401/403 marca `NEEDS_RECONNECT`, retry deja estados seguros, create concurrente con cancelación no crea un evento persistente y delete limpia cualquier evento creado por la carrera.
- [ ] Verificar concurrencia real con dos requests de reprogramación/acción y confirmar que solo una versión gana y la restricción SQL mantiene integridad.
- [ ] Ejecutar gate local en este orden:

  ```bash
  cd api
  npm test -- --runInBand --watchman=false src/calendar src/sync src/appointments src/availability
  npm run test:e2e -- --runInBand --watchman=false admin-appointments.e2e-spec.ts calendar-outbox.e2e-spec.ts
  npm run build
  git diff --check
  ```

- [ ] Confirmar PostgreSQL local, migraciones al día, ausencia de migraciones nuevas, secretos fuera del diff y workspace con solo `app`, `api`, `context` como carpetas principales.
- [ ] Actualizar `context/tasks/backlog.md` con evidencia, limitaciones explícitas y fecha de T-016; crear el commit final.

## Definition of Done T-016

- Contratos HTTP y errores coinciden con la spec aprobada.
- Todas las acciones están scoped al artista autenticado y son seguras ante repetición/concurrencia.
- Reprogramar verifica disponibilidad interna y externa antes del commit, excluye la propia cita y mantiene la integridad SQL.
- Calendar update/delete reutiliza el ID determinista, es idempotente y se recupera ante evento externo ausente.
- Outbox, retries, incidencias y `NEEDS_RECONNECT` funcionan para las tres operaciones sin datos sensibles.
- PostgreSQL local, unitarias, E2E y build pasan; no se añade Docker, Flutter ni migración Prisma.
- Cada tarea tiene un commit pequeño y la rama permanece integrable por Trunk-Based Development.
