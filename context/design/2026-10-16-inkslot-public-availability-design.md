# Diseño: disponibilidad pública y selección de horarios

**Fecha:** 2026-10-16  
**Estado:** aprobado para planificación  
**Alcance:** slice T-012 — disponibilidad pública, calendario de fechas y rueda de horarios

## Objetivo

Reemplazar el placeholder público de fechas por un flujo real que consulte la disponibilidad segura de una solicitud privada y permita seleccionar un día y un horario. La API calculará los slots con la configuración persistida, las restricciones de la solicitud, los bloqueos internos, las citas existentes y Google Calendar. Flutter mostrará los datos reales con la composición mobile-first del prototipo, incluyendo calendario, estados de carga y rueda curva.

La revisión, el ticket, la confirmación transaccional y la idempotencia pertenecen al slice T-013 y no se implementan aquí.

## Dependencias y decisiones

- PostgreSQL local está activo y contiene las migraciones actuales.
- `AvailabilityEngine` ya implementa el cálculo puro con zona IANA, duración, paso, aviso mínimo, horizonte, restricciones, bloqueos, ocupaciones, buffer y fallo cerrado de Calendar.
- `AdminAvailabilityService` ya persiste zona horaria, jornada semanal, paso, buffer, aviso mínimo y horizonte.
- `AdminBlocksService` ya administra bloqueos de disponibilidad.
- `CalendarService.queryBusy` ya consulta `freeBusy`, normaliza intervalos UTC y responde `503 CALENDAR_UNAVAILABLE` cuando Calendar no puede verificarse.
- `BookingRequestsService` ya valida tokens hash-only, expiración, revocación, estado de solicitud y resumen público seguro.
- El endpoint canónico será `/v1/public/reservations/:token/availability`; no se usará la ruta histórica `/slots`.
- No se añade migración Prisma en T-012.
- El token público debe permanecer en la ruta profunda necesaria para resolver la reserva, pero nunca se enviará a analytics, logs, almacenamiento persistente ni referrer intencional.

## Contrato API público

### Endpoint

```text
GET /v1/public/reservations/:token/availability?from=YYYY-MM-DD&to=YYYY-MM-DD
```

`from` y `to` son fechas locales inclusivas interpretadas en la zona horaria del estudio. Ambos son obligatorios, deben usar `YYYY-MM-DD`, `from` no puede ser posterior a `to` y el rango máximo será de 31 días. El servicio no aceptará timestamps ni zonas horarias proporcionadas por el cliente.

### Respuesta exitosa

```json
{
  "timezone": "America/Guayaquil",
  "days": [
    {
      "date": "2026-10-23",
      "slots": [
        {
          "startAt": "2026-10-23T15:00:00.000Z",
          "endAt": "2026-10-23T18:00:00.000Z"
        }
      ]
    }
  ]
}
```

Los intervalos son semiabiertos `[startAt, endAt)`, siempre ISO-8601 UTC. Un rango válido sin disponibilidad responde `200` con `days: []`; no se inventan horarios de demostración.

### Errores públicos

| Condición | HTTP | Código | Comportamiento |
|---|---:|---|---|
| Parámetros ausentes, fecha inválida o rango mayor a 31 días | 400 | `BAD_REQUEST` | No consulta Prisma ni Calendar. |
| Token inexistente | 404 | `TOKEN_NOT_FOUND` | Mensaje seguro sin confirmar datos privados. |
| Token vencido | 410 | `TOKEN_EXPIRED` | No devuelve disponibilidad. |
| Token revocado/cerrado/cancelado | 410 | `TOKEN_REVOKED` | No devuelve disponibilidad. |
| Solicitud ya reservada | 409 | `ALREADY_BOOKED` | La UI muestra el estado agendado. |
| Solicitud sin zona/configuración segura | 503 | `AVAILABILITY_NOT_CONFIGURED` | No ofrece slots. |
| Calendar desconectado, reautenticación requerida o error externo | 503 | `CALENDAR_UNAVAILABLE` | Falla cerrado; nunca equivale a agenda libre. |

Los errores mantienen el envelope `{ error: { code, message } }` existente y no exponen tokens OAuth, IDs internos, contacto, mensajes crudos de Google ni consultas SQL.

## Arquitectura API

### Acceso público a la solicitud

`BookingRequestsService` añadirá una operación interna `resolvePublicAvailabilityContext(token)` que reutiliza la búsqueda hash-only y las mismas reglas de expiración/revocación de `resolvePublic`. El contexto interno no se serializa directamente y contendrá solo:

```ts
export type PublicAvailabilityContext = {
  requestId: string;
  artistId: string;
  status: 'pending';
  durationMinutes: number;
  timezone: string;
  expiresAt: Date;
  minDate: string | null;
  maxDate: string | null;
  allowedWeekdays: number[] | null;
  allowedWindows: Array<{ startLocal: string; endLocal: string }> | null;
};
```

Una solicitud `booked` se traduce a `409 ALREADY_BOOKED`; las demás transiciones públicas conservan `404`/`410` según la implementación actual. `RequestsModule` exportará `BookingRequestsService` y no importará `AvailabilityModule`, evitando dependencia circular.

### Servicio y controller de disponibilidad

`AvailabilityModule` importará `RequestsModule` y `CalendarModule`, registrará `AvailabilityEngine` y añadirá:

- `api/src/availability/public-availability.dto.ts` — query `from`/`to` y validación de formato.
- `api/src/availability/public-availability.service.ts` — orquestación de contexto, datos persistidos, Calendar y motor puro.
- `api/src/availability/public-availability.controller.ts` — `GET /public/reservations/:token/availability`.

El servicio calculará el rango UTC de consulta usando el inicio local de `from` y el inicio del día siguiente a `to` en la zona del estudio. Cargará:

- `StudioSettings` del artista.
- `WeeklyAvailability` ordenado por día y hora, convertido a `HH:mm` local.
- `AvailabilityBlock` cuyo intervalo se intersecte con el rango consultado.
- `Appointment` cuyo estado no sea `CANCELLED` y cuyo intervalo se intersecte con el rango.
- `CalendarService.queryBusy` para la misma ventana y zona IANA.

El servicio pasará al `AvailabilityEngine` la duración y restricciones del contexto, la configuración del estudio, los intervalos internos/externos y `calendarVerifiable: true` solo después de una consulta Calendar exitosa. No implementará caché en esta rebanada.

## Flujo Flutter

### Modelos y datos

Se crearán modelos públicos separados de los modelos administrativos:

```dart
class PublicReservation {
  final String status; // pending | booked
  final String artistDisplayName;
  final int durationMinutes;
  final String timezone;
  final PublicRestrictions restrictions;
  final DateTime expiresAt;
}

class PublicAvailability {
  final String timezone;
  final List<AvailabilityDay> days;
}

class AvailabilityDay {
  final DateTime date;
  final List<AvailabilitySlot> slots;
}

class AvailabilitySlot {
  final DateTime startAt;
  final DateTime endAt;
}
```

`PublicReservationRepository` consumirá el `ApiClient` inyectado:

```dart
Future<PublicReservation> getReservation(String token);

Future<PublicAvailability> getAvailability(
  String token, {
  required DateTime from,
  required DateTime to,
});
```

El repositorio codificará únicamente fechas locales `YYYY-MM-DD` en la query y convertirá los intervalos recibidos a `DateTime` UTC. Fechas, estados o slots malformados producirán un error tipado de datos, no un horario parcial silencioso.

### Controller Provider

`PublicReservationController extends ChangeNotifier` manejará un solo token público y tendrá estados independientes para resumen y disponibilidad:

```dart
enum PublicReservationStatus {
  idle,
  loading,
  active,
  booked,
  expired,
  revoked,
  error,
}

enum PublicAvailabilityStatus {
  idle,
  loading,
  ready,
  empty,
  calendarUnavailable,
  offline,
  error,
}
```

El controller expondrá `loadReservation(token)`, `loadAvailability(token, from, to)`, `selectDate(date)`, `selectSlot(slot)`, `retryReservation()` y `retryAvailability()`. La selección de día/slot permanecerá en memoria y no se enviará a ningún endpoint hasta T-013.

### Composición y navegación

`InkSlotApp` será dueño de una instancia `HttpApiClient`, la cerrará en `dispose` y pasará las dependencias compartidas a `AppRouter`. Esto corrige la composición para que las rutas públicas y administrativas usen el mismo `API_BASE_URL` y cliente web con cookies, sin duplicar clientes no gestionados.

Se conservarán y reemplazarán estas rutas:

```text
/r/:token
/r/:token/dates
```

`/r/:token` cargará el resumen real y dejará de mostrar nombre, duración, vigencia o restricciones fixture. `/r/:token/dates` cargará el rango visible y mostrará el calendario real. La ruta seguirá conteniendo el token porque es el deep link público establecido; no se copiará a `extra`, almacenamiento o analytics.

## UI y fidelidad visual

### Bienvenida y calendario

- Mantener mosaico, logo, tipografías, paleta, superficies, radios y CTA del prototipo.
- Cambiar el resumen fixture por duración, vigencia y restricciones reales.
- Mostrar estados `active`, `booked`, `expired`, `cancelled`, `sin_horarios`, `sin_red` y `error_agenda` con componentes de estado seguros.
- En calendario, marcar solo días que la API devuelve con al menos un slot.
- Mantener safe areas, scroll vertical, baseline mobile 390×844 y layout útil en desktop.
- No habilitar días sin disponibilidad ni convertir días bloqueados en estados visuales seleccionables.

### Rueda de horarios

La rueda mostrará los slots del día elegido, con horario activo en píldora cobre y glow, vecinos legibles arriba/abajo, flechas y gestos táctiles. Usará `AnimationController`, `Transform`, escala/opacidad progresivas y `GestureDetector`/scroll semántico. El estado seleccionado será accesible por teclado y cada opción tendrá target mínimo de 44 px.

Con `MediaQuery.disableAnimations`, la rueda será estática, conservará la jerarquía visual y no bloqueará la selección. No se usará WebGL ni una dependencia nueva de rueda si el comportamiento puede resolverse con widgets Flutter y los tokens existentes.

## Estados y seguridad

| Estado | Respuesta/condición | UI |
|---|---|---|
| Cargando resumen | petición inicial | Skeleton discreto sin datos inventados. |
| Cargando disponibilidad | consulta de rango | Loader de horarios. |
| `days: []` | API válida sin slots | Estado sin horarios y CTA de reintento/cambio de rango cuando aplique. |
| `410` | enlace vencido/revocado | Pantalla segura sin PII. |
| `409` | solicitud ya agendada | Estado agendado, sin calendario seleccionable. |
| `503` | Calendar no verificable | Estado agenda no verificable, sin slots. |
| error de red | transporte fallido | Mensaje de conexión y reintento. |
| slot seleccionado | estado local | Preparado para T-013, sin confirmar ni prometer reserva. |

El cliente no tratará un error de Calendar como una lista vacía. La API será la autoridad para restricciones, duración, zona, aviso, horizonte, bloqueos y ocupaciones; Flutter no recalculará disponibilidad ni podrá habilitar slots fuera de la respuesta.

## Pruebas y criterios de aceptación

### API

- Unit tests para query date-only, rango máximo, contexto del token, mapeo de restricciones, cálculo de rango UTC y estados HTTP.
- Unit tests para `PublicAvailabilityService` con `CalendarService` falso, `AvailabilityEngine` real y Prisma falso.
- E2E contra PostgreSQL local para token activo, rango vacío, restricciones, bloqueo interno, cita existente, aislamiento, token vencido/revocado, solicitud booked y Calendar unavailable.
- Verificar que la respuesta no contiene client, contact, IDs internos, token, OAuth ni datos del calendario.

### Flutter

- Tests de serialización de resumen/disponibilidad y fechas UTC.
- Tests del repositorio con `ApiClient` falso para query, error envelope y estados HTTP.
- Tests del controller para loading, ready, empty, booked, expired, offline y Calendar unavailable.
- Widget tests para bienvenida real, calendario vacío, días seleccionables, cambio de día, rueda activa, reduced motion, error y reintento.
- Router tests para deep link público y preservación de rutas admin.
- Ejecutar `fvm dart format`, `fvm flutter analyze`, `fvm flutter test` y `fvm flutter build web`.

### Definition of Done

- El enlace privado muestra datos reales del backend y puede consultar disponibilidad real.
- Los slots publicados respetan todas las restricciones y la disponibilidad de Calendar.
- Calendar no verificable nunca produce slots aparentemente libres.
- El usuario puede elegir día y horario sin mocks, aunque todavía no pueda confirmar.
- Las pantallas reproducen la composición del prototipo y cubren loading/empty/error/reduced-motion.
- API unit/E2E y Flutter tests/analyze/build pasan con PostgreSQL local activo.
- T-012 queda documentado en `context/tasks/backlog.md`; T-013 permanece pendiente.

## Fuera de alcance

- Ticket/revisión 3D y confirmación.
- `POST /v1/public/reservations/:token/confirm`.
- `Idempotency-Key`, bloqueo transaccional, consumo del token y outbox.
- Creación/actualización de citas y eventos de Google Calendar.
- Nuevas políticas de negocio, datos demo permanentes o almacenamiento de selección.
