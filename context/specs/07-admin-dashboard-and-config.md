# SPEC-ADMIN — RF-02, RF-03, RF-13..RF-16

Pantallas exactas según ZIP README: login, Inicio con resumen de pendientes/próximas/incidencias; Nueva solicitud; Enlace listo copiar/compartir; Solicitudes con filtros, detalle, historial, renovar, revocar, cerrar; Citas con lista/detalle, reprogramar, completar, no asistió, cancelar y retry; Agenda con jornada semanal/bloqueos/reglas/Calendar conectar-desconectar-reconectar.

## Contratos
`GET /v1/admin/dashboard` → `{pendingRequests, upcomingAppointments, syncIssues, nextAppointments}` (datos reales); `GET/PUT /v1/admin/availability`; `GET/POST/DELETE /v1/admin/blocks`; `GET/PUT /v1/admin/settings` (slot step, minimum notice, horizon, buffer, timezone).

## UX
Provider por feature, request state loading/loaded/empty/error; ningún botón que aparente guardar puede ser demo. Copiar/compartir por web share con fallback clipboard; hojas inferiores iOS; errores de formulario inline; botón deshabilitado durante submit y reintento idempotente; KPI sincronización.

## AC
Solicitud pendiente visible hasta agendada o cerrada; filtro no pierde estado; revocación afecta acceso público; banner de Calendar reconectar funciona; reintento conserva historial.
