# Diseño: conexión OAuth de Google Calendar

**Fecha:** 2026-10-15  
**Estado:** aprobado para implementación local  
**Alcance:** primera rebanada de la integración Calendar

## Objetivo

Conectar un artista autenticado de InkSlot con Google Calendar mediante OAuth Authorization Code, almacenar el refresh token cifrado en PostgreSQL y dejar visible el estado de la integración para que las siguientes rebanadas puedan consultar `freeBusy` y sincronizar citas.

El calendario seleccionado para el entorno local será el calendario dedicado `InkSlot`. El calendario `primary` queda como alternativa de configuración, no como selección silenciosa.

## Decisiones

- El flujo OAuth vive exclusivamente en NestJS; Flutter solo iniciará la URL y mostrará el resultado.
- Se usará `googleapis`/Calendar v3 detrás de una interfaz propia `CalendarProvider` para que los tests no dependan de Google.
- `state` será un valor aleatorio de un solo uso, almacenado como hash en PostgreSQL y asociado al artista autenticado; expirará después de diez minutos.
- El callback validará `state` antes de intercambiar el authorization code.
- El flujo solicitará `access_type=offline`, `include_granted_scopes=true` y consentimiento explícito cuando se necesite obtener un refresh token.
- El refresh token se cifrará con AES-256-GCM usando una clave local de 32 bytes; nunca se retornará en una respuesta HTTP ni se guardará en Flutter.
- Después del intercambio, el backend consultará `calendarList.list` y seleccionará el calendario configurado como `InkSlot`; si no existe una coincidencia única, la conexión no se marcará como activa y se devolverá un error seguro de selección.
- `CalendarConnectionStatus` incorporará `NEEDS_RECONNECT` para distinguir una credencial revocada de una desconexión intencional.
- La configuración de zona horaria del estudio continuará en `StudioSettings`; la integración no inferirá la zona desde el calendario.

## Endpoints de esta rebanada

- `GET /v1/admin/calendar/status`: devuelve `disconnected`, `connected`, `error` o `needs_reconnect`, además del nombre seguro del calendario y timestamps.
- `GET /v1/admin/calendar/connect`: requiere sesión admin, crea el estado OAuth de un solo uso y devuelve la URL de autorización.
- `GET /v1/admin/calendar/callback`: valida `state`, intercambia el código, selecciona `InkSlot`, cifra el refresh token y devuelve un JSON seguro de resultado para la verificación local. La pantalla Flutter podrá envolver este flujo después sin modificar el intercambio OAuth.
- `POST /v1/admin/calendar/disconnect`: revoca la conexión local y elimina el token cifrado; no modifica citas internas.
- `POST /v1/admin/calendar/reconnect`: inicia un nuevo flujo OAuth conservando las citas internas.

El callback no devolverá tokens, códigos OAuth, correos de Google ni detalles de errores del proveedor.

## Persistencia

Se conservará `CalendarConnection` como vínculo por artista y se añadirá `calendarName` para que el estado administrativo no tenga que exponer detalles del evento ni realizar una llamada externa. `CalendarConnectionStatus` incorporará `NEEDS_RECONNECT`. También se añadirá una entidad temporal de estado OAuth con `artistId`, `stateHash`, `expiresAt` y `consumedAt`, con índices para expiración y búsqueda segura. La migración será compatible con PostgreSQL local y Prisma.

## Errores y seguridad

- Sesión ausente o inválida: `401 AUTH_INVALID`.
- `state` inexistente, expirado o consumido: `400 OAUTH_STATE_INVALID`.
- Consentimiento denegado: `400 OAUTH_ACCESS_DENIED`.
- Calendario `InkSlot` inexistente o ambiguo: `409 CALENDAR_SELECTION_REQUIRED`.
- Credenciales revocadas o inválidas: se marca `needs_reconnect` y se informa un CTA administrativo.
- Fallos de Google: `503 CALENDAR_UNAVAILABLE` con mensaje seguro.
- Los logs solo incluirán códigos, request id y el identificador interno; nunca authorization codes, refresh tokens, client secrets ni URLs completas de consentimiento.

## Pruebas

- Unitarias para cifrado/descifrado, expiración y consumo único de `state`, selección única de `InkSlot` y mapeo de errores Google.
- E2E con Prisma/PostgreSQL para endpoints protegidos, persistencia de conexión, desconexión y ausencia de secretos en respuestas.
- Adapter fake para mantener las pruebas deterministas y reservar la prueba real de Google para una verificación manual local.

## Fuera de alcance de esta rebanada

- Consulta `freeBusy` en disponibilidad pública.
- Creación, actualización y cancelación de eventos de citas.
- Outbox, worker, backoff e incidencias de sincronización.
- Pantalla Flutter administrativa de Calendar; se conectará después de estabilizar el contrato HTTP.

## Referencias

- `context/specs/06-google-calendar.md`
- `context/adr/ADR-002-booking-integrity-and-calendar.md`
- `context/architecture/api-contracts.md`
- `context/open-questions.md`
