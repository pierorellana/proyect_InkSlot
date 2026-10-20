# SPEC-CALENDAR — RF-04, RF-11, RF-16

## OAuth
Conexión admin por flujo OAuth Authorization Code + PKCE donde aplique, `state` anti-CSRF; scopes mínimos necesarios para freeBusy + gestión de eventos en calendario elegido. Token refresh cifrado en reposo, nunca en Flutter. Admin elige `calendarId`, zona del estudio configurada separadamente. Desconexión invalida integración, no borra citas internas.

## Operaciones
- Consultar disponibilidad externa por `freeBusy.query` con rango y time zone explícitos.
- Crear un evento por cita; persistir `externalEventId`, `etag`, `syncedAt` y `calendarId`.
- Reprogramar evento con mismo ID; cancelar evento; cada operación idempotente.
- Outbox durable + worker con backoff exponencial, jitter, límite y dead-letter/incidencia; no asumir exactly-once en proveedor. Si retries tras timeout, buscar por ID/correlación para no duplicar.
- `GET /v1/admin/calendar/status`, `/connect`, `/callback`, `POST /disconnect`, `POST /reconnect`, `GET /v1/admin/sync-issues`, `POST /v1/admin/sync-issues/:id/retry`.

## Fuente de verdad y divergencias
DB determina si solicitud/cita existe; Calendar bloquea ocupaciones manuales ajenas y es proyección eventual. Si evento externo se modifica manualmente, **política de conflicto aún requiere decisión** (véase `open-questions.md`). Por seguridad, eventos externos ocupados prevalecen al crear/reprogramar, y cualquier discrepancia genera incidencia.

## AC
AC-06 integración pendiente visible; AC-09 sin freeBusy no dar disponibilidad; AC-10 fallos recuperables; pérdida de consentimiento → `needs_reconnect` y CTA admin; reintento no crea dos eventos.

## Estado de implementación

OAuth, `freeBusy`, creación/actualización/eliminación, outbox, reintentos, incidencias y reconexión están implementados para el MVP local. Sigue abierta la política de reconciliación cuando el tatuador edita o elimina manualmente un evento, además de la validación OAuth con el dominio final.
