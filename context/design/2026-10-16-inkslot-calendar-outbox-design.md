# Diseño: worker local de outbox y sincronización de citas con Google Calendar

**Fecha:** 2026-10-16  
**Estado:** aprobado para documentar e iniciar el plan de implementación  
**Alcance:** T-014: creación idempotente de eventos, worker in-process, retries e incidencias

## Objetivo

Procesar de forma durable los eventos `appointment.calendar.create` producidos por la confirmación pública. La cita interna continúa siendo la fuente de verdad en PostgreSQL; Google Calendar es una proyección eventual. Un fallo externo no deshace una cita confirmada, pero deja `syncStatus`, outbox e incidencia en un estado visible y recuperable.

## Dependencias y límites

- T-013 ya crea `OutboxEvent` con `type = appointment.calendar.create`, `aggregateId = appointment.id`, `status = PENDING` y payload `{ appointmentId, operation: 'create' }` dentro de la transacción de confirmación.
- Se reutilizan `OutboxEvent`, `CalendarEvent`, `SyncIssue`, `Appointment.syncStatus` y `CalendarConnection.status`; no se añade una migración Prisma en T-014.
- El worker se ejecuta dentro del proceso NestJS local. No se añade Docker, Redis, una cola externa ni un segundo servicio obligatorio.
- T-014 solo procesa creación de eventos. Reprogramación, cancelación, eliminación y actualización del mismo evento pertenecen a T-016.
- No se implementa todavía la pantalla administrativa de incidencias; T-014 entrega sus endpoints API y el modelo necesario para T-017.
- La política de divergencia por edición manual de eventos Google permanece abierta; este slice solo garantiza la sincronización inicial y sus fallos recuperables.

## Decisión de arquitectura

Se añadirá un módulo `sync` con tres responsabilidades separadas:

1. `OutboxWorkerService`: polling configurable, claim atómico, lease, procesamiento por lotes y apagado ordenado.
2. `CalendarSyncService`: interpreta el payload, carga la cita y conexión, construye un evento seguro, llama al adaptador Calendar y persiste el resultado.
3. `SyncIssuesService` y controlador admin: lista incidencias del artista autenticado y permite reencolar manualmente un evento fallido.

`CalendarProvider` seguirá ocultando `googleapis`. Se extenderá solo con las operaciones necesarias para este slice:

```ts
export type CalendarEventInput = {
  refreshToken: string;
  calendarId: string;
  eventId: string;
  summary: string;
  description: string;
  startAt: Date;
  endAt: Date;
  timeZone: string;
};

export type CalendarEventResult = {
  externalEventId: string;
  etag: string | null;
};

export interface CalendarProvider {
  createEvent(input: CalendarEventInput): Promise<CalendarEventResult>;
  getEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<CalendarEventResult | null>;
}
```

Las operaciones OAuth, `freeBusy`, revocación y listado de calendarios existentes conservan sus contratos actuales.

## Worker y claim de outbox

`@nestjs/schedule` registrará un intervalo in-process. La configuración tendrá estos nombres y valores predeterminados locales:

| Variable | Predeterminado | Propósito |
|---|---:|---|
| `OUTBOX_WORKER_ENABLED` | `true` fuera de `NODE_ENV=test` | activar el polling en desarrollo |
| `OUTBOX_POLL_INTERVAL_MS` | `5000` | frecuencia de sondeo |
| `OUTBOX_BATCH_SIZE` | `10` | máximo de eventos por ciclo |
| `OUTBOX_LEASE_MS` | `120000` | tiempo de recuperación de un `PROCESSING` abandonado |
| `OUTBOX_MAX_ATTEMPTS` | `5` | intentos máximos por evento |
| `OUTBOX_RETRY_BASE_MS` | `30000` | base del backoff |
| `OUTBOX_RETRY_MAX_MS` | `900000` | límite del backoff |
| `OUTBOX_JITTER_RATIO` | `0.2` | variación aleatoria ±20% |

El worker no ejecutará dos drenajes simultáneos dentro del mismo proceso. La seguridad entre procesos se mantiene en PostgreSQL mediante un claim transaccional equivalente a:

```sql
WITH candidate AS (
  SELECT id
  FROM outbox_events
  WHERE (
    (status = 'PENDING' AND (next_attempt_at IS NULL OR next_attempt_at <= now()))
    OR (status = 'PROCESSING' AND next_attempt_at <= now())
  )
  ORDER BY COALESCE(next_attempt_at, created_at), created_at, id
  FOR UPDATE SKIP LOCKED
  LIMIT 1
)
UPDATE outbox_events AS event
SET status = 'PROCESSING',
    attempts = event.attempts + 1,
    next_attempt_at = now() + CAST($1 AS interval)
FROM candidate
WHERE event.id = candidate.id
RETURNING event.id, event.aggregate_id, event.type, event.payload, event.attempts;
```

El lease reutiliza `nextAttemptAt`, por lo que no requiere columnas nuevas. Si un proceso muere en `PROCESSING`, otro worker puede reclamarlo después del lease. Esto implica entrega at-least-once; el handler externo debe ser idempotente.

## Creación idempotente del evento

Para `appointment.calendar.create` el servicio:

1. Valida que el payload contenga únicamente un `appointmentId` UUID y la operación `create`.
2. Carga la cita, el cliente, el `StudioSettings` y la conexión Calendar del mismo artista.
3. Si existe `CalendarEvent` para la cita, marca el outbox como completado y la cita como `SYNCED` sin llamar a Google.
4. Deriva un `eventId` estable como el SHA-256 hexadecimal de `inkslot:appointment:<appointmentId>`; no se genera un ID diferente en cada retry.
5. Envía a Google `calendar.events.insert` con el calendario persistido, `sendUpdates: 'none'`, fechas UTC, zona IANA del estudio y un evento mínimo:
   - `summary`: `InkSlot — <nombre del cliente>`.
   - `description`: `Reserva InkSlot · <duración> min`.
   - `start.dateTime` y `end.dateTime` en RFC3339.
6. Persiste `CalendarEvent.externalEventId`, `etag` y `lastSyncedAt`, marca `Appointment.syncStatus = SYNCED` y `OutboxEvent.status = COMPLETED` en una transacción corta.
7. Si Google responde conflicto al insertar con el ID determinista, consulta ese mismo ID con `events.get`; si existe, lo trata como éxito. Así un timeout posterior a una creación no genera un segundo evento.

El nombre del cliente se usa únicamente dentro del calendario seleccionado del propio artista. No se incluyen email, teléfono, token, refresh token, hashes, IDs internos ni información de anticipo. Los logs solo contienen tipo de operación, código seguro, intento y correlación.

## Retries, estados e incidencias

Después de reclamar una fila, la llamada externa ocurre fuera de la transacción de claim. El cierre se persiste en otra transacción:

- Éxito: `CalendarEvent` creado o recuperado, cita `SYNCED`, outbox `COMPLETED`; cualquier `SyncIssue.OPEN` de la misma cita/operación pasa a `RESOLVED`.
- Error transitorio del proveedor, timeout o `503`: si `attempts < OUTBOX_MAX_ATTEMPTS`, outbox vuelve a `PENDING` y `nextAttemptAt` recibe backoff exponencial con jitter. La cita permanece `PENDING`.
- Error de autorización (`CALENDAR_REAUTH_REQUIRED`): conexión pasa a `NEEDS_RECONNECT`, cita `FAILED`, outbox `FAILED` e incidencia abierta sin reintento automático.
- Conexión ausente/no conectada, payload inválido, cita inexistente o evento incompatible: cita `FAILED`, outbox `FAILED` e incidencia abierta con código seguro.
- Error transitorio después del último intento: cita `FAILED`, outbox `FAILED` e incidencia abierta.

Los códigos públicos de incidencia serán estables (`CALENDAR_REAUTH_REQUIRED`, `CALENDAR_UNAVAILABLE`, `APPOINTMENT_NOT_FOUND`, `OUTBOX_PAYLOAD_INVALID`, `SYNC_ATTEMPTS_EXHAUSTED`) y los mensajes guardados serán seguros, en español y sin detalles crudos del proveedor.

## API administrativa de incidencias

Se añadirán, bajo `AdminSessionGuard` y alcance por artista:

```text
GET  /v1/admin/sync-issues
POST /v1/admin/sync-issues/:id/retry
```

La lista devuelve como máximo 50 incidencias ordenadas por `lastAttemptAt DESC`, con `id`, `appointmentId`, `operation`, `code`, `message`, `status`, `lastAttemptAt` y `createdAt`. No devuelve tokens ni datos de contacto.

`POST retry` solo acepta una incidencia abierta o fallida del artista autenticado. Reutiliza el outbox asociado, lo devuelve a `PENDING` con `attempts = 0` y `nextAttemptAt = now()`, devuelve la cita a `PENDING` y conserva la misma identidad determinista del evento. Si la incidencia no existe o no pertenece al artista, responde el error seguro existente.

## Pruebas y Definition of Done

### Unitarias

- Payload exacto de `events.insert`, zona y fechas RFC3339.
- ID determinista, `sendUpdates: 'none'` y recuperación por conflicto/`getEvent`.
- Claim `SKIP LOCKED`, recuperación de lease y bloqueo de drenajes simultáneos.
- Éxito, retry con jitter, agotamiento, reautenticación, conexión ausente y payload inválido.
- Estados `SYNCED`, `PENDING`, `FAILED`, outbox e incidencia.
- Alcance administrativo por artista y reencolado sin duplicar eventos.

### E2E PostgreSQL

Con un `CalendarProvider` falso y sin llamadas reales a Google se comprobará que:

- La confirmación T-013 deja un outbox pendiente.
- Un drenaje exitoso crea exactamente un `CalendarEvent`, marca cita sincronizada y completa el outbox.
- Un timeout reintenta y una creación ya realizada se recupera por ID sin duplicarse.
- Se agotan los intentos y se crea una incidencia segura.
- La reautenticación marca `NEEDS_RECONNECT` sin exponer secretos.
- Dos workers concurrentes no producen dos eventos externos ni dos filas `CalendarEvent`.
- El retry administrativo reusa el mismo outbox y queda limitado al artista dueño.

### Gate

PostgreSQL local y Prisma al día; API unitarias, E2E y build Nest; `git diff --check`; escaneo de secretos; workspace con solo `app`, `api` y `context` como carpetas principales. Flutter no requiere cambios en T-014 porque ya interpreta `pending`, `synced` y `failed`; su UI administrativa de incidencias queda para T-017.

## Fuera de alcance

- Reprogramar, cancelar o eliminar eventos externos.
- Detección de ediciones manuales mediante polling de Calendar o webhooks.
- Pantalla Flutter administrativa de incidencias.
- Mensajería, notificaciones, Docker, Redis y despliegue.

## Referencias

- `context/specs/05-appointments-and-booking.md`
- `context/specs/06-google-calendar.md`
- `context/adr/ADR-002-booking-integrity-and-calendar.md`
- `context/design/2026-10-15-inkslot-calendar-oauth-design.md`
- `context/design/2026-10-15-inkslot-calendar-freebusy-design.md`
- `context/tasks/backlog.md`
