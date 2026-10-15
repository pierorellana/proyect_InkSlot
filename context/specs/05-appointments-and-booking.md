# SPEC-APPOINTMENTS — RF-10, RF-12..RF-14, RF-16

## Confirmación transaccional
`POST /v1/public/reservations/:token/confirm` con header `Idempotency-Key` y `{startAt}`. Validar token, expiración, solicitudes sin cita, hora/duración, freeBusy reciente, restricciones; en transacción bloquear la solicitud (`SELECT FOR UPDATE`), insertar cita con rango excluyente, consumir token y escribir evento outbox. Si conflicto retornar `409 SLOT_UNAVAILABLE` y slots refrescados. Misma idempotencia → mismo resultado; distinto payload y misma clave → `409 IDEMPOTENCY_REUSED`.

## Máquina de estados cita
`confirmed → completed|no_show|cancelled`; `confirmed → rescheduled` es acción auditable que actualiza intervalo y conserva cita con historial de versiones; no crear cita extra. Separar `syncStatus = pending|synced|failed|needs_reconnect` de estado de negocio. Si Calendar falla al crear evento **después** de commit DB, informar `confirmed + sync_pending`, encolar reintento y exponer incidencia admin. Si falla freeBusy ANTES de commit, no confirmar.

## Cancelar/reprogramar
Solo admin P0. Reprogramar verifica nuevo hueco, evita solapamiento, emite `AppointmentRescheduled`; cancelar libera intervalo inmediatamente en DB y encola eliminación/actualización externa. Si sync externa falla, continuar con incidencia visible. Estados terminales no deben reprogramarse sin reapertura explícita (no P0).

## Endpoints
`GET /v1/admin/appointments`, `GET /v1/admin/appointments/:id`, `PATCH /v1/admin/appointments/:id/reschedule`, `POST /v1/admin/appointments/:id/cancel`, `/complete`, `/no-show`; `GET /v1/public/reservations/:token/appointment` protegido por token de consulta de reserva, sin exponer datos de otros.

## AC
AC-05 concurrencia 1 gana; AC-06 confirmación registra DB + sincronizada o pending; AC-08 cancelación consistente eventual; segundo click idempotente; estados visuales completos.
