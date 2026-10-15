# InkSlot Availability Engine Implementation Plan

> SDD slice: RD-01..RD-12 → pruebas puras → algoritmo timezone-aware → verificación → commit.

**Objetivo:** implementar el cálculo determinista de inicios disponibles sin conectarlo todavía a HTTP, Prisma ni Google Calendar real.

**Fuentes:** `context/specs/04-availability-engine.md`, `context/quality/acceptance-matrix.md` AC-03/04/09, `context/adr/ADR-002-booking-integrity-and-calendar.md` y `context/design/2026-10-15-inkslot-platform-design.md`.

## Contrato

- Entrada: zona IANA del estudio, fechas locales inclusivas, jornada semanal, duración, paso, aviso, horizonte, buffer, restricciones de solicitud, bloqueos internos, citas internas, ocupaciones externas y un indicador de Calendar verificable.
- Salida: `timezone` y días que tengan al menos un slot `{startAt,endAt}` expresado en ISO UTC.
- La semana usa `0=domingo ... 6=sábado`, alineada con los valores de demo del prototipo.
- Los intervalos son semiabiertos `[start,end)`; la duración debe caber completamente en la ventana.
- Si Calendar no es verificable, el motor falla cerrado con `CALENDAR_UNAVAILABLE` y no devuelve slots.

## No incluido

- Persistencia o lectura de `booking_requests`, bloques y citas.
- Consulta OAuth/freeBusy, caché, endpoint `/public/reservations/:token/availability` y ViewModel Flutter.
- Confirmación: siempre deberá recalcular y aplicar la exclusión PostgreSQL en otro slice.

## Criterios de salida

- No se ofrecen sesiones que no quepan, crucen pausa, bloqueos, ocupaciones o restricciones.
- Se respetan aviso mínimo, horizonte, paso, buffer entre ocupaciones y zona IANA.
- Se cubren días prohibidos, límites, deduplicación, orden, Calendar offline y cruce de UTC.

## Pasos

1. Escribir pruebas de duración, pausas, ocupaciones, restricciones, timezone y Calendar offline.
2. Implementar tipos de entrada/salida y error de dominio.
3. Implementar materialización de ventanas locales y filtrado de intervalos UTC con Luxon.
4. Ejecutar formato, lint, build y tests API.
5. Registrar evidencia y dejar el endpoint como siguiente slice explícito.
