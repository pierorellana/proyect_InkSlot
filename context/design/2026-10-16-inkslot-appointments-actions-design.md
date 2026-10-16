# Diseño: acciones administrativas de citas y sincronización Calendar

**Fecha:** 2026-10-16  
**Estado:** propuesta para revisión de la spec escrita  
**Alcance:** T-016 — listado/detalle de citas, reprogramación, cancelación, completar, no-show y proyección Calendar update/delete

## Objetivo

Entregar el slice API administrativo para que el artista consulte sus citas y ejecute acciones de ciclo de vida sin romper la integridad de PostgreSQL ni duplicar eventos de Google Calendar. La base de datos continúa siendo la fuente de verdad de la cita; Calendar es una proyección eventual administrada por el mismo worker/outbox de T-014.

La reprogramación exige verificar el nuevo intervalo con la disponibilidad interna y `freeBusy` antes de modificar PostgreSQL. La cancelación es inmediata en PostgreSQL y su eliminación externa es eventual. Las acciones de completar y marcar no-show solo afectan el estado interno y la auditoría.

## Decisiones y límites

- Se extiende el pipeline `sync` de T-014; no se crea un worker ni una cola paralela.
- Se reutilizan `Appointment.version`, `CalendarEvent`, `OutboxEvent`, `SyncIssue`, `AuditLog` y `CalendarConnection`.
- No se añade una migración Prisma en T-016.
- El modelo no tiene `AppointmentStatus.RESCHEDULED`; reprogramar conserva `CONFIRMED`, cambia el intervalo, incrementa `version` y registra auditoría.
- Cancelar, completar y no-show solo se permiten desde `CONFIRMED`.
- Reprogramar solo se permite desde `CONFIRMED` y no crea una segunda cita.
- Una acción repetida sobre el mismo estado es idempotente: devuelve el estado actual sin crear otro outbox ni otra auditoría.
- Una versión obsoleta para una acción que todavía no alcanzó el estado destino responde `409 APPOINTMENT_VERSION_CONFLICT`.
- Cancelar no se bloquea por Calendar; reprogramar sí se bloquea si no se puede verificar el intervalo externo.
- La pantalla Flutter administrativa de citas queda fuera de T-016; este slice entrega API, persistencia, sincronización y contratos para el slice visual posterior.
- No se implementan webhooks, polling de divergencias manuales ni reapertura de estados terminales.

## Contratos HTTP

Todos los endpoints requieren `AdminSessionGuard`, filtran por `request.user.id` y conservan el prefijo global `/v1`.

### Listado

```text
GET /v1/admin/appointments?status=confirmed|completed|cancelled|no_show&cursor=<opaque>
```

La respuesta es `{ items, nextCursor }`, con máximo 20 elementos, orden `startAt ASC, id ASC`. Sin `status` se devuelven todos los estados. Cada item contiene únicamente:

```json
{
  "id": "uuid",
  "status": "confirmed",
  "syncStatus": "pending",
  "startAt": "2026-11-03T15:00:00.000Z",
  "endAt": "2026-11-03T16:30:00.000Z",
  "version": 1,
  "client": { "name": "Cliente" },
  "durationMinutes": 90
}
```

El listado no incluye teléfono, email, referencia de pago, tokens, refresh tokens ni detalles internos de sincronización.

### Detalle

```text
GET /v1/admin/appointments/:id
```

Devuelve la cita del artista autenticado, su cliente administrativo permitido, duración, intervalo, estado, `syncStatus`, `version`, CalendarEvent activo si existe y auditoría ordenada ascendentemente. Una cita de otro artista responde el error seguro `404 NOT_FOUND`.

### Reprogramar

```text
PATCH /v1/admin/appointments/:id/reschedule
Content-Type: application/json

{ "startAt": "2026-11-05T15:00:00.000Z", "version": 1 }
```

`startAt` debe ser UTC con milisegundos (`YYYY-MM-DDTHH:mm:ss.sssZ`) y `version` un entero positivo. `endAt` se calcula con `BookingRequest.durationMinutes`; nunca se acepta desde el cliente.

Respuesta: la representación actual de la cita con `status = confirmed`, nuevo intervalo, `syncStatus = pending` y `version` incrementada.

### Acciones de estado

```text
POST /v1/admin/appointments/:id/cancel
POST /v1/admin/appointments/:id/complete
POST /v1/admin/appointments/:id/no-show
Content-Type: application/json

{ "version": 1 }
```

La respuesta devuelve la representación actualizada. Cancelar deja `syncStatus = pending` hasta que la eliminación externa se complete. Completar y no-show no crean operaciones Calendar nuevas y conservan el `syncStatus` que ya tenga la cita.

## Máquina de estados y transacciones

Las acciones se ejecutan en una transacción PostgreSQL `Serializable`, con reintento para `P2034`, `40001` y `40P01`. Dentro de la transacción se obtiene la cita por `id + artistId` y se valida la versión.

```text
CONFIRMED ── reschedule ──> CONFIRMED (nuevo intervalo, version + 1, outbox update)
CONFIRMED ── cancel ───────> CANCELLED (version + 1, outbox delete)
CONFIRMED ── complete ─────> COMPLETED (version + 1)
CONFIRMED ── no-show ──────> NO_SHOW (version + 1)
```

En reprogramación, antes de la transacción de escritura se verifica:

1. Zona horaria y configuración de estudio.
2. Duración de la solicitud asociada.
3. Jornada, restricciones de la solicitud, aviso mínimo, horizonte y bloqueos.
4. Otras citas internas del artista, excluyendo la propia cita que se mueve.
5. `freeBusy` de Google para el intervalo destino. Si Calendar no es verificable, se responde `503 CALENDAR_UNAVAILABLE` y no se modifica la cita.

Si el nuevo intervalo coincide exactamente con el actual, la operación es un no-op idempotente. Para intervalos distintos se conserva una política conservadora: un busy externo que se solapa con el destino bloquea la reprogramación, aunque corresponda al evento actual; no se intenta inferir la identidad de un busy agregado por Google.

La transacción de escritura:

- actualiza la cita y aumenta `version`;
- registra `AuditLog` con `actorType = ADMIN`, `actorId`, entidad `appointment` y cambios de estado/intervalo sin PII innecesaria;
- crea `appointment.calendar.update` o `appointment.calendar.delete` en `OutboxEvent` con payload exacto `{ appointmentId, operation }`;
- deja la operación interna confirmada aunque Calendar falle después del commit.

En una cancelación, el delete se encola incluso si todavía no existe `CalendarEvent`. Así una carrera con el create de T-014 puede limpiar un evento que haya sido creado externamente. El handler de create vuelve a comprobar que la cita está `CONFIRMED`; si ya está cancelada, completa el outbox como no-op sin crear un evento.

## Contrato Calendar y outbox

`CalendarProvider` se amplía con:

```ts
updateEvent(input: CalendarEventInput): Promise<CalendarEventResult>;
deleteEvent(input: {
  refreshToken: string;
  calendarId: string;
  eventId: string;
}): Promise<void>;
```

`CalendarService` conserva la carga de conexión y descifrado en memoria. `GoogleCalendarProvider` usará `events.update` con el mismo `calendarId`, `eventId`, resumen, descripción, fechas UTC, zona IANA y `sendUpdates: 'none'`. El update representa el estado interno actual y no genera un ID nuevo. Si Google responde que el evento no existe, se intentará crear la misma proyección con el mismo ID determinista; si la creación devuelve un conflicto de ID, se consultará `getEvent` y se considerará exitoso solo si el evento ya existe. `events.delete` con 404 se tratará como éxito.

El `CalendarSyncService` despachará estrictamente las tres operaciones:

- `create`: solo crea si la cita sigue `CONFIRMED`; una cita cancelada produce un éxito no-op.
- `update`: carga la cita actual, construye la proyección completa y actualiza o recrea el mismo evento; el resultado actualiza `CalendarEvent` y `etag`.
- `delete`: calcula el mismo ID determinista, elimina el evento si existe y borra el `CalendarEvent` local solo después del éxito.

La finalización será transaccional:

- update exitoso: upsert de `CalendarEvent`, cita `SYNCED`, outbox `COMPLETED` y resolución de la incidencia abierta;
- delete exitoso/no-op: elimina `CalendarEvent`, cita `SYNCED`, outbox `COMPLETED` y resuelve la incidencia;
- create no-op por cancelación: completa solo el outbox de create y conserva el estado de sincronización para que el delete complete la proyección;
- error transitorio: retry con el backoff/jitter de T-014;
- 401/403: conexión `NEEDS_RECONNECT`, incidencia segura sin retry automático;
- error terminal o agotamiento: cita `FAILED`, outbox `FAILED` e incidencia segura.

Los resultados internos del sync distinguirán explícitamente entre una operación aplicada y un no-op: `create` cancelado finaliza el outbox sin `CalendarEvent` y sin cambiar la cita a `SYNCED`; `update` y `delete` solo finalizan como éxito después de aplicar sus efectos locales correspondientes.

Los mensajes públicos y persistidos nunca contienen mensajes crudos de Google, refresh tokens, email, teléfono, pago ni IDs internos en el contenido del evento.

## Errores HTTP

| Situación | Código | Resultado |
|---|---|---|
| Cita inexistente o de otro artista | `404 NOT_FOUND` | No revela existencia ajena |
| DTO inválido | `400 BAD_REQUEST` | ValidationPipe existente |
| Estado no permitido | `409 APPOINTMENT_STATE_CONFLICT` | No modifica datos |
| Versión obsoleta | `409 APPOINTMENT_VERSION_CONFLICT` | No modifica datos |
| Solapamiento interno/externo | `409 SLOT_UNAVAILABLE` | Incluye solo datos seguros |
| Calendar no verificable al reprogramar | `503 CALENDAR_UNAVAILABLE` | No modifica la cita |
| Error de persistencia no recuperable | `503 SERVICE_UNAVAILABLE` | Mensaje seguro |

## Pruebas y Definition of Done

### Unitarias

- DTOs rechazan fechas no UTC, versiones no positivas y campos desconocidos.
- Servicio prueba ownership, listado paginado, detalle, transiciones válidas/invalidas, no-op idempotente, versión obsoleta y auditoría.
- Reprogramación cubre jornada, restricciones, bloqueos, citas internas excluyendo la actual, freeBusy no verificable y conflicto de slot.
- Provider prueba `events.update`, `events.delete`, 404 idempotente, 401/403 y errores transitorios.
- Handler sync prueba update/delete, recreación con el mismo ID, no-op de create cancelado y resultados idempotentes.

### E2E PostgreSQL

Con fake Calendar y fixtures aislados se verifica:

- listado/detalle solo del artista autenticado;
- reprogramación válida con una sola cita, una auditoría y un outbox update;
- concurrencia/version conflict sin doble cambio;
- cancelación interna inmediata y delete externo eventual;
- complete/no-show sin operaciones Calendar;
- retry, reauth, evento externo borrado, no duplicados y cancelación concurrente con create;
- errores seguros y ausencia de tokens, contacto o referencia de pago en respuestas/eventos.

### Fuera de alcance

- Pantalla Flutter de citas y dashboard visual;
- webhooks/polling de cambios manuales en Calendar;
- reapertura de citas terminales;
- notificaciones por correo, WhatsApp o Instagram;
- migraciones de esquema, Docker o servicios externos adicionales.

## Referencias

- `context/specs/05-appointments-and-booking.md`
- `context/specs/06-google-calendar.md`
- `context/specs/07-admin-dashboard-and-config.md`
- `context/adr/ADR-002-booking-integrity-and-calendar.md`
- `context/design/2026-10-16-inkslot-calendar-outbox-design.md`
- `context/architecture/api-contracts.md`
- `context/architecture/data-model.md`
- `context/open-questions.md`
