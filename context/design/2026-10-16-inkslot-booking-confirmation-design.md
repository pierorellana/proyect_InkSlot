# Diseño: confirmación pública idempotente y resultado de reserva

**Fecha:** 2026-10-16  
**Estado:** aprobado para implementación local  
**Alcance:** T-013 vertical: confirmación transaccional, revisión/ticket, resultado y consulta posterior.

## Objetivo

Permitir que un cliente confirme un horario sin cuenta, resistiendo doble clic, reintentos de red y confirmaciones concurrentes. La reserva interna se confirma en PostgreSQL; la sincronización Google queda durablemente en outbox para T-014.

## Decisiones y límites

- Reutilizar `Appointment`, `IdempotencyKey`, `OutboxEvent`, `BookingRequest`, `BookingToken`, la restricción única por solicitud y `appointments_no_overlap`.
- No añadir migración Prisma en T-013.
- Exigir `CalendarService.queryBusy` antes del commit; no crear eventos Google en este slice.
- Crear `appointment.calendar.create` con estado `PENDING`; T-014 procesará el evento y actualizará `syncStatus`.
- No persistir tokens claros, claves claras, PII, IDs internos ni horarios seleccionados en localStorage, analytics, logs o `GoRouter.extra`.
- No implementar reprogramación, cancelación, completar, no-show, worker/retry ni acciones administrativas de citas.

## Contrato HTTP público

### Confirmar

```http
POST /v1/public/reservations/:token/confirm
Idempotency-Key: <1..128 caracteres imprimibles>
Content-Type: application/json

{"startAt":"2026-10-20T15:00:00.000Z"}
```

Reglas:

- La clave es obligatoria, imprimible y de máximo 128 caracteres.
- `startAt` es RFC3339 UTC con sufijo `Z); se normaliza a ISO UTC.
- La duración se toma de la solicitud; el cliente no la envía.
- Campos desconocidos son rechazados.
- Se hashean la clave y el token con SHA-256.
- El payload hash se calcula sobre `{"startAt":"<ISO UTC normalizado>"}`.
- El `scope` usa un prefijo fijo y el hash del token; nunca se persiste el token claro.

Respuesta 201:

```json
{
  "status": "confirmed",
  "syncStatus": "pending",
  "startAt": "2026-10-20T15:00:00.000Z",
  "endAt": "2026-10-20T18:00:00.000Z",
  "timezone": "America/Guayaquil"
}
```

Durante 24 horas, misma clave y mismo payload devuelven exactamente el código y cuerpo persistidos, incluso con el token consumido. Misma clave con payload diferente devuelve `409 IDEMPOTENCY_REUSED`.

### Consultar la reserva

```http
GET /v1/public/reservations/:token/appointment
```

Para una solicitud `BOOKED), incluido el token consumido, devuelve solo:

```json
{
  "status": "confirmed",
  "syncStatus": "pending",
  "startAt": "2026-10-20T15:00:00.000Z",
  "endAt": "2026-10-20T18:00:00.000Z",
  "timezone": "America/Guayaquil"
}
```

No devuelve IDs internos, cliente, contacto, token hash ni datos de Calendar. Si aún no hay cita responde `404 APPOINTMENT_NOT_FOUND`.

## Flujo de confirmación

El nuevo módulo `appointments` coordina contexto seguro de `requests`, disponibilidad, Calendar freeBusy y Prisma.

### Preflight sin escritura

1. Validar header y body.
2. Buscar replay por `scope + keyHash`; devolverlo o rechazar payload diferente.
3. Resolver el token como solicitud pendiente.
4. Validar expiración, revocación, estado `PENDING` y ausencia de cita.
5. Reutilizar el cargador y `AvailabilityEngine` para jornada, restricciones, bloqueos, citas, duración y buffer del intervalo.
6. Consultar `CalendarService.queryBusy` para el intervalo exacto.
7. Si el hueco no es válido, devolver `409 SLOT_UNAVAILABLE` con disponibilidad pública refrescada.
8. Si Calendar o la configuración no son verificables, devolver `503 CALENDAR_UNAVAILABLE` o `503 AVAILABILITY_NOT_CONFIGURED`, sin escrituras.

### Transacción serializable

1. Bloquear `BookingRequest` con `SELECT ... FOR UPDATE`.
2. Revalidar solicitud `PENDING`, token vigente/no consumido/no revocado y ausencia de cita.
3. Insertar `Appointment(status=CONFIRMED, syncStatus=PENDING)`.
4. Cambiar solicitud a `BOOKED` e incrementar `version`.
5. Consumir el token recibido.
6. Crear el outbox:
   ```json
   {
     "type": "appointment.calendar.create",
     "aggregateId": "<appointmentId>",
     "payload": {"appointmentId": "<appointmentId>", "operation": "create"}
   }
   ```
   El payload no contiene PII ni token.
7. Crear `IdempotencyKey` con respuesta 201, cuerpo seguro y expiración de 24 horas.
8. Confirmar y devolver el cuerpo persistido.

La unicidad de `requestId` y la exclusión GiST impiden doble cita y solapamientos. Los SQLSTATE `40001` y `40P01` podrán reintentar la transacción completa de forma limitada; un solapamiento se convierte en `409 SLOT_UNAVAILABLE`.

## Errores públicos

- `400 BAD_REQUEST`: body, fecha o clave inválidos.
- `404 TOKEN_NOT_FOUND` / `APPOINTMENT_NOT_FOUND`.
- `409 IDEMPOTENCY_REUSED`, `SLOT_UNAVAILABLE` o `ALREADY_BOOKED`.
- `410 TOKEN_EXPIRED` o `TOKEN_REVOKED`.
- `503 CALENDAR_UNAVAILABLE` o `AVAILABILITY_NOT_CONFIGURED`.

Todos usan `{ error: { code, message } }`; los conflictos solo incluyen disponibilidad pública, nunca PII.

## Flujo Flutter

El feature público añadirá modelos de confirmación/cita y:

```dart
enum PublicConfirmationStatus {
  idle, loading, confirmed, conflict, alreadyBooked,
  expired, revoked, calendarUnavailable, offline, error
}

Future<PublicConfirmation> confirmReservation(
  String token,
  DateTime startAt, {
  required String idempotencyKey,
});

Future<PublicAppointment> getAppointment(String token);
```

El controlador conserva la clave en memoria durante retries del mismo payload, genera otra al cambiar horario, bloquea confirmaciones paralelas y limpia la selección solo al confirmar. No guarda token, horario o clave fuera de memoria.

`/r/:token/review` renderiza el ticket 3D con artista, fecha, hora en zona del estudio y duración. Sin selección en memoria muestra un estado seguro y vuelve a fechas.

`/r/:token/result` renderiza `confirmed + pending`, `confirmed + synced`, conflicto 409, vencido/revocado, ya reservado, offline y Calendar no verificable. “Ver mi reserva” consulta el endpoint de cita, incluso después de recargar. Las animaciones `tkIn`, confirmación, `stamp` y `ringOut` respetan reduced motion, foco, semántica y targets de 44 px.

## Pruebas y Definition of Done

### API

- Unitarias para validación, normalización/hash, replay exacto, payload diferente, token, freeBusy, configuración y constraints.
- E2E con PostgreSQL para confirmación, outbox, token consumido, `BOOKED`, consulta posterior, aislamiento, ausencia de PII, replay y carrera concurrente.
- Un fallo de freeBusy no deja escrituras.
- Exactamente una confirmación concurrente gana.

### Flutter

- Models/repository para 201, consulta posterior y envelopes.
- Controller para clave estable, cambio de clave, loading, éxito, conflicto, offline, Calendar y estados de token.
- Widget tests para ticket, loader, resultado pendiente, conflicto, deep link sin selección, CTA y reduced motion.
- Sin Google real ni red externa en tests.

### Gate

PostgreSQL local y migraciones al día; API unit/E2E/build; Flutter format/test/analyze/build Web; backlog actualizado con T-013 y T-014 como siguiente slice. Prototipo, ZIP, PDF, secretos y artefactos generados no se versionan.

## Fuera de alcance

Worker/retry/backoff y creación real del evento Google; reprogramar, cancelar, completar, no-show; panel admin de citas/incidencias; mensajería.

## Referencias

- `context/specs/05-appointments-and-booking.md`
- `context/specs/08-public-flutter-experience.md`
- `context/adr/ADR-002-booking-integrity-and-calendar.md`
- `context/design/2026-10-15-inkslot-platform-design.md`
- `context/design/prototype-inventory.md`
- `context/tasks/backlog.md`

