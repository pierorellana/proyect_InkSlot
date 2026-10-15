# SPEC-REQUESTS — RF-06..RF-08, RF-13, RF-15

## Entidades y estados
Solicitud: `pending`, `booked`, `closed`, `cancelled`; estado del **enlace** separado: `active`, `expired`, `revoked`, `consumed`. La expiración no elimina la solicitud ni la prueba de anticipo. Una solicitud puede vincular **máximo una cita activa**.

## Reglas
- Admin define `durationMinutes` + restricciones opcionales (`allowedWeekdays`, `minDate`, `maxDate`, `allowedTimeWindows`), heredan horario general y únicamente lo restringen.
- Token `crypto.randomBytes(32)` URL-safe, secreto almacenado **solo como hash** SHA-256/HMAC, expiración UTC, rotación atómica y comparación constant-time cuando corresponda.
- Crear/renovar/revocar/cerrar deja auditoría; link anterior no funciona después de renovar.
- `booked` impide crear segunda cita; consulta pública de reserva ya confirmada devuelve solo información propia.

## Endpoints
`POST /v1/admin/booking-requests`, `GET /v1/admin/booking-requests?status=&cursor=`, `GET /v1/admin/booking-requests/:id`, `POST /v1/admin/booking-requests/:id/renew`, `POST /v1/admin/booking-requests/:id/revoke`, `POST /v1/admin/booking-requests/:id/close`.
`GET /v1/public/reservations/:token`: retorno público minimizado.

## AC
AC-01 nueva solicitud aparece en pendientes; AC-02 token válido sin login; AC-07 expirado HTTP 410 + renovación conservando historial; revocado/cancelado informan sin detalles de PII; renovar no duplica solicitud.
