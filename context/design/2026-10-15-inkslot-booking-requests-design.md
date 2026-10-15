# Diseño: solicitudes de reserva, clientes y enlaces públicos

**Fecha:** 2026-10-15  
**Estado:** aprobado para implementación local  
**Alcance:** slice T-010 de solicitudes y tokens

## Objetivo

Entregar el flujo backend que permite al artista crear una solicitud de reserva, asociarla con un cliente propio, generar un enlace público temporal y administrarlo mediante renovación, revocación y cierre. El siguiente slice podrá consumir el endpoint público para calcular disponibilidad real.

## Dependencias y corrección de integridad

La migración inicial modeló `Client` sin `artistId`, aunque los endpoints administrativos son siempre por artista. Permitir seleccionar un cliente global permitiría cruzar información entre artistas. Esta rebanada corregirá el modelo añadiendo:

- `Client.artistId` obligatorio y relación `Artist.clients`.
- Índice por `(artistId, createdAt)`.
- Resolución de clientes existentes siempre con `{ id, artistId }`.
- Creación inline siempre con el `artistId` autenticado.

La prueba de persistencia existente se actualizará para crear los clientes con propietario explícito. No se cambiará el alcance de clientes ni se añadirán búsquedas globales.

## Entidades y estados

Se conservarán `BookingRequest`, `BookingToken` y sus enums Prisma existentes.

### Solicitud

- `PENDING`: puede tener un enlace activo y puede renovarse.
- `BOOKED`: queda reservado para el slice de confirmación; no se podrá crear una segunda cita.
- `CANCELLED`: revocación administrativa terminal.
- `EXPIRED`: no existe un enlace activo y la solicitud puede renovarse; conserva historial y datos del anticipo.
- `CLOSED`: cierre administrativo terminal.

### Enlace

El estado del enlace no se almacenará como enum; se derivará de sus campos:

- `active`: `revokedAt = null`, `expiresAt > now`, solicitud accionable.
- `expired`: `revokedAt = null`, `expiresAt <= now`.
- `revoked`: `revokedAt != null` o solicitud `CANCELLED`/`CLOSED`.
- `consumed`: `consumedAt != null`; el estado de la solicitud seguirá determinando si el cliente puede consultar un resultado reservado.

La lectura pública de un enlace expirado marcará la solicitud `EXPIRED` solo cuando no exista otro token no revocado y vigente. Renovar una solicitud `EXPIRED` la devolverá a `PENDING` dentro de la misma transacción.

## Contratos administrativos

El nuevo módulo NestJS será `requests` y expondrá:

- `POST /v1/admin/booking-requests`
- `GET /v1/admin/booking-requests?status=&cursor=`
- `GET /v1/admin/booking-requests/:id`
- `POST /v1/admin/booking-requests/:id/renew`
- `POST /v1/admin/booking-requests/:id/revoke`
- `POST /v1/admin/booking-requests/:id/close`

Todas estas rutas requieren `AdminSessionGuard` y filtran por `request.user.id`.

### Crear

El body acepta exactamente uno de `clientId` o `client` inline:

```json
{
  "client": {
    "name": "Cliente ejemplo",
    "email": "cliente@example.com",
    "phone": "+593000000000"
  },
  "depositVerified": true,
  "durationMinutes": 180,
  "minDate": "2026-10-20",
  "maxDate": "2026-11-30",
  "allowedWeekdays": [2, 3, 4, 5, 6],
  "allowedWindows": [{ "startLocal": "10:00", "endLocal": "20:00" }],
  "tokenTtlHours": 48
}
```

Reglas:

- `name` es obligatorio; `email` y `phone` son opcionales.
- `depositVerified` debe ser `true`; de lo contrario `422 DEPOSIT_NOT_VERIFIED`.
- `durationMinutes` debe ser mayor que cero.
- Fechas locales son `YYYY-MM-DD`, inclusivas y `minDate <= maxDate`.
- Días están en `0..6`, sin duplicados.
- Franjas locales usan `HH:mm`, con inicio anterior al fin.
- `tokenTtlHours` es opcional, entero entre 1 y 720; el valor por defecto es 48.
- Las restricciones solo reducen la disponibilidad general y se conservarán como JSON validado.

La respuesta incluye la solicitud administrativa, el cliente propio y el enlace claro una sola vez:

```json
{
  "request": {
    "id": "uuid",
    "status": "pending",
    "durationMinutes": 180,
    "restrictions": {
      "minDate": "2026-10-20",
      "maxDate": "2026-11-30",
      "allowedWeekdays": [2, 3, 4, 5, 6],
      "allowedWindows": [{ "startLocal": "10:00", "endLocal": "20:00" }]
    },
    "depositVerifiedAt": "2026-10-15T15:00:00.000Z",
    "createdAt": "2026-10-15T15:00:00.000Z",
    "client": {
      "id": "uuid",
      "name": "Cliente ejemplo",
      "email": "cliente@example.com",
      "phone": "+593000000000"
    }
  },
  "link": {
    "path": "/r/<opaque-token>",
    "expiresAt": "2026-10-17T15:00:00.000Z"
  }
}
```

El token opaco se entrega únicamente en la respuesta de creación o renovación. No aparecerá en listados, detalles, auditorías, logs ni errores.

### Listado y detalle

El listado devuelve como máximo 20 elementos, ordenados por `createdAt DESC, id DESC`. `cursor` es una cadena base64url opaca que contiene la posición `(createdAt,id)`; la respuesta incluye `nextCursor` o `null`. El filtro `status` acepta los cinco estados de `BookingRequestStatus` en minúsculas.

El detalle incluye los metadatos de solicitud, cliente propio, estado de enlace vigente y auditoría necesaria para la pantalla administrativa, pero nunca el token claro.

### Renovar

`POST /renew` requiere una solicitud que no esté `BOOKED`, `CANCELLED` o `CLOSED`. En una transacción:

1. Revoca todos los tokens no revocados de la solicitud.
2. Genera un nuevo token aleatorio y guarda solo su hash.
3. Si el estado era `EXPIRED`, lo cambia a `PENDING`.
4. Registra `token_renewed` en `AuditLog`.

La respuesta contiene el nuevo enlace claro y su vencimiento. El enlace anterior falla con `410 TOKEN_REVOKED`.

### Revocar y cerrar

`POST /revoke` revoca los enlaces activos y cambia la solicitud a `CANCELLED`. `POST /close` revoca los enlaces activos y cambia la solicitud a `CLOSED`. Ambos son idempotentes para solicitudes ya en el mismo estado, registran auditoría y nunca eliminan el cliente ni la evidencia del anticipo.

Para una solicitud `BOOKED`, una acción administrativa incompatible devuelve `409 ALREADY_BOOKED`. Para estados terminales incompatibles con la acción se devuelve `400 BAD_REQUEST` con mensaje seguro.

## Contrato público

`GET /v1/public/reservations/:token` no requiere sesión. La API hashea el token recibido y nunca busca por texto claro. Para un enlace activo devuelve únicamente:

```json
{
  "status": "pending",
  "artist": { "displayName": "InkSlot Artist" },
  "durationMinutes": 180,
  "timezone": "America/Guayaquil",
  "restrictions": {
    "minDate": "2026-10-20",
    "maxDate": "2026-11-30",
    "allowedWeekdays": [2, 3, 4, 5, 6],
    "allowedWindows": [{ "startLocal": "10:00", "endLocal": "20:00" }]
  },
  "expiresAt": "2026-10-17T15:00:00.000Z"
}
```

No se devuelven nombre, email, teléfono, notas internas, `artistId`, `requestId`, `tokenHash`, anticipo ni datos de otros clientes. Si la solicitud ya está `BOOKED`, la respuesta solo cambia `status` a `booked`; los datos de la cita pertenecen a otro slice.

Errores públicos:

- Token inexistente: `404 NOT_FOUND`.
- Token expirado: `410 TOKEN_EXPIRED`.
- Token revocado, solicitud cancelada o cerrada: `410 TOKEN_REVOKED`.
- Solicitud reservada: respuesta segura con `status: booked`, no un error.

## Persistencia, transacciones y auditoría

La generación de solicitud, cliente inline, token y auditoría se ejecutará en una transacción Prisma. Las operaciones de renovación, revocación, cierre y la transición de expiración usarán la misma conexión transaccional para evitar enlaces parcialmente actualizados.

El token se genera con `crypto.randomBytes(32).toString('base64url')` y se persiste con `sha256(token)` en hexadecimal. `BookingToken.tokenHash` continúa siendo la única representación persistida del secreto. La auditoría usará `actorType = ADMIN`, `actorId = artistId`, `entityType = 'booking_request'`, el UUID de la solicitud y acciones `created`, `token_renewed`, `revoked` o `closed`; ningún cambio contendrá el token ni contactos innecesarios.

## Seguridad y errores

- Las rutas admin sin sesión responden `401 AUTH_INVALID`.
- Todas las consultas admin agregan `artistId`; nunca aceptan un artista desde el body.
- `clientId` de otro artista responde `404 NOT_FOUND` sin confirmar su existencia.
- Campos desconocidos son rechazados por el `ValidationPipe` global.
- No se registran tokens, hashes, URLs públicas completas ni PII innecesaria.
- La expiración, revocación y cancelación no eliminan solicitudes, clientes ni auditoría.
- La throttling global existente protege la lectura pública; no se añade una funcionalidad de mensajería.

## Pruebas

- Unitarias para generación/hash, TTL, validación de restricciones, estados y cursor.
- E2E con PostgreSQL local para aislamiento de artistas, creación inline/existente, auditoría, renovación atómica, revocación/cierre y resolución pública.
- Verificar que respuestas admin de creación/renovación contienen el enlace una sola vez y que listados, detalles, errores y auditorías no contienen el token.
- Verificar `401`, `404`, `410`, `422`, `409`, solicitudes sin anticipo y token antiguo después de renovar.
- Actualizar la prueba de persistencia para `Client.artistId` y ejecutar el conjunto completo API.

## Fuera de alcance

- Endpoint público de disponibilidad y llamada `CalendarService.queryBusy`.
- Confirmación, idempotencia, citas, constraint de concurrencia y outbox.
- Pantallas Flutter de solicitudes o reserva pública.
- Envío de enlaces por correo, WhatsApp o SMS.
- Edición de clientes y política productiva de retención/PII.

## Referencias

- `context/specs/02-clients-and-deposits.md`
- `context/specs/03-booking-requests-and-tokens.md`
- `context/specs/04-availability-engine.md`
- `context/architecture/api-contracts.md`
- `context/architecture/data-model.md`
- `context/adr/ADR-003-auth-and-public-tokens.md`
- `context/adr/ADR-002-booking-integrity-and-calendar.md`
- `context/open-questions.md`
