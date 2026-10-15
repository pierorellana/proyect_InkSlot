# Diseño: consulta de disponibilidad externa con Google Calendar

**Fecha:** 2026-10-15  
**Estado:** aprobado para implementación local  
**Alcance:** segunda rebanada de la integración Calendar

## Objetivo

Conectar la conexión OAuth persistida de un artista con el motor de disponibilidad mediante una consulta segura de `freeBusy`. Esta rebanada entrega intervalos ocupados externos normalizados a UTC, sin crear todavía el endpoint público de disponibilidad ni consultar Google desde Flutter.

## Contexto y límites

La rebanada anterior ya implementa OAuth, selección única del calendario `InkSlot`, cifrado del refresh token y los estados `CONNECTED`/`NEEDS_RECONNECT`. El motor `AvailabilityEngine` ya acepta `externalBusy` y falla cerrado cuando Calendar no es verificable.

Este slice no implementa solicitudes públicas, validación de tokens de reserva, persistencia de citas, eventos de Google, outbox ni la pantalla administrativa Flutter. El siguiente slice podrá consumir `CalendarService.queryBusy` al construir la disponibilidad pública.

## Decisión

Se usará la alternativa de adaptador + servicio:

- `CalendarProvider` seguirá aislando el SDK `googleapis` del dominio.
- El proveedor expondrá `freeBusy(input)` con refresh token, calendario, rango UTC y zona IANA explícitos.
- `GoogleCalendarProvider` invocará `calendar.freebusy.query` con `timeMin`, `timeMax`, `timeZone` e `items: [{ id: calendarId }]`.
- `CalendarService` cargará la conexión del artista, verificará que esté `CONNECTED`, desencriptará el refresh token y delegará la consulta.
- La respuesta del servicio será una lista de intervalos `{startAt: Date, endAt: Date}` en UTC, compatible con `AvailabilityInterval`.

No se llamará a Google desde `AvailabilityEngine`: el motor continuará siendo puro, determinista y testeable con datos ya cargados.

## Contratos

El proveedor añadirá estos tipos:

```ts
export type CalendarBusyQuery = {
  refreshToken: string;
  calendarId: string;
  timeMin: Date;
  timeMax: Date;
  timeZone: string;
};

export type CalendarBusyInterval = {
  startAt: Date;
  endAt: Date;
};

freeBusy(input: CalendarBusyQuery): Promise<CalendarBusyInterval[]>;
```

El servicio expondrá:

```ts
queryBusy(
  artistId: string,
  input: { timeMin: Date; timeMax: Date; timeZone: string },
): Promise<CalendarBusyInterval[]>;
```

Las fechas deben ser válidas, `timeMin < timeMax` y la zona debe ser una IANA válida. Los intervalos de Google son semiabiertos: inicio inclusivo y fin exclusivo. Se conservará esa semántica al mapearlos.

## Flujo de datos

```text
CalendarService.queryBusy
  -> Prisma CalendarConnection (artistId, status, calendarId, encryptedRefreshToken)
  -> CalendarCrypto.decrypt
  -> CalendarProvider.freeBusy
  -> Google calendar.freebusy.query
  -> validar calendars[calendarId].errors y busy[]
  -> CalendarBusyInterval[] UTC
  -> AvailabilityEngine.externalBusy (en el siguiente slice)
```

La consulta usará explícitamente el rango recibido y la zona del estudio; no inferirá la zona desde Google ni ampliará silenciosamente el rango.

## Errores y estados

- Sin conexión, conexión no `CONNECTED`, token ilegible o rango inválido: `503 CALENDAR_UNAVAILABLE` desde el servicio, salvo validación de entrada que corresponda a `400` en una capa HTTP futura.
- Error de autorización de Google o refresh token revocado: el proveedor devolverá un código interno de reautenticación; el servicio marcará la conexión como `NEEDS_RECONNECT` y responderá `503 CALENDAR_UNAVAILABLE` sin detalles sensibles.
- Error por calendario en una respuesta HTTP 200, intervalo sin inicio/fin, fecha inválida o intervalo invertido: se tratará como indisponibilidad completa, no como calendario libre.
- Cualquier otro error del proveedor se mapeará a `CALENDAR_UNAVAILABLE`; no se expondrán tokens, códigos OAuth, cabeceras ni mensajes crudos de Google.

El fallo es cerrado: ningún error de `freeBusy` producirá una lista vacía considerada libre.

## Pruebas

- `CalendarProvider`/Google: comprobar el payload exacto de `freebusy.query`, el `calendarId` seleccionado, rango RFC3339, zona explícita, mapeo UTC y errores de calendario.
- `CalendarService`: conexión válida con refresh token desencriptado, ausencia de conexión, estado no conectado, error normal del proveedor y error de reautenticación con transición a `NEEDS_RECONNECT`.
- E2E del módulo: usar un proveedor falso y Prisma local; no hacer llamadas de red a Google.
- Verificación del slice: formato, lint, build, unit tests y E2E existentes.

## Seguridad y operación local

- El refresh token permanece cifrado en PostgreSQL y solo existe en memoria durante la llamada al proveedor.
- El token no se imprime ni se incluye en excepciones, respuestas o fixtures.
- No se añade Docker ni infraestructura externa; la verificación usa PostgreSQL local y las credenciales ya configuradas en `api/.env`.
- No habrá caché en esta rebanada; disponibilidad y confirmación futura podrán exigir lecturas actuales.

## Referencias

- `context/specs/04-availability-engine.md`
- `context/specs/06-google-calendar.md`
- `context/adr/ADR-002-booking-integrity-and-calendar.md`
- `context/architecture/api-contracts.md`
- `context/design/2026-10-15-inkslot-calendar-oauth-design.md`
- [Google Calendar freeBusy query](https://developers.google.com/workspace/calendar/api/v3/reference/freebusy/query)
