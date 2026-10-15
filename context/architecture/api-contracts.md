# Contratos HTTP iniciales (propuesta v1)

Base URL `/v1`, JSON UTF-8, ISO-8601 UTC, `X-Request-Id`, errores tipados `{error:{code,message,requestId,details?}}`; nunca retornar tokens OAuth ni información de otros clientes.

## Administración (auth)
- `POST /auth/login`, `GET /auth/me`, `POST /auth/logout`
- `GET /admin/dashboard`
- `GET/PUT /admin/availability`; `GET/POST/DELETE /admin/blocks[/:id]`; `GET/PUT /admin/settings`
- `POST/GET /admin/booking-requests`; `GET /admin/booking-requests/:id`; `POST /admin/booking-requests/:id/renew|revoke|close`
- `GET /admin/appointments`; `GET /admin/appointments/:id`; `PATCH /admin/appointments/:id/reschedule`; `POST /admin/appointments/:id/cancel|complete|no-show`
- `GET /admin/calendar/status|connect`; `GET /admin/calendar/callback`; `POST /admin/calendar/disconnect|reconnect`
- `GET /admin/sync-issues`; `POST /admin/sync-issues/:id/retry`

## Público (token de solicitud)
- `GET /public/reservations/:token`
- `GET /public/reservations/:token/availability?from=&to=`
- `POST /public/reservations/:token/confirm` (`Idempotency-Key: uuid`)
- `GET /public/reservations/:token/appointment`

## Ejemplos
```json
{"client":{"name":"Cliente ejemplo","phone":"+593..."},"depositVerified":true,"durationMinutes":180,"restrictions":{"allowedWeekdays":[2,3,4,5,6],"minDate":"2026-10-20","maxDate":"2026-11-30"},"tokenTtlHours":48}
```
```json
{"timezone":"America/Guayaquil","days":[{"date":"2026-10-23","slots":[{"startAt":"2026-10-23T15:00:00Z","endAt":"2026-10-23T18:00:00Z"}]}]}
```
```json
{"startAt":"2026-10-23T15:00:00Z"}
```
```json
{"appointmentId":"uuid","status":"confirmed","syncStatus":"pending","startAt":"2026-10-23T15:00:00Z","endAt":"2026-10-23T18:00:00Z"}
```

## Errores pactados
`400 BAD_REQUEST`, `401 AUTH_INVALID`, `403 FORBIDDEN`, `404 NOT_FOUND`, `409 SLOT_UNAVAILABLE|ALREADY_BOOKED|IDEMPOTENCY_REUSED`, `410 TOKEN_EXPIRED|TOKEN_REVOKED`, `422 INVALID_RESTRICTIONS|DEPOSIT_NOT_VERIFIED`, `429 RATE_LIMITED`, `503 CALENDAR_UNAVAILABLE|SERVICE_UNAVAILABLE`.

**Nota**: endpoints y DTOs aquí son diseño propuesto a partir de documento PDF y prototipo, no rutas existentes ni llamadas ya implementadas.
