# InkSlot Admin Availability Configuration Plan

> SDD slice: contrato admin → pruebas e2e → guard → persistencia de configuración/jornada → verificación → commit.

**Objetivo:** permitir al artista autenticado guardar y consultar la configuración base que alimentará el motor de disponibilidad.

**Fuentes:** `context/specs/04-availability-engine.md`, `context/architecture/api-contracts.md`, `context/architecture/data-model.md`, `context/adr/ADR-002-booking-integrity-and-calendar.md`.

## Contrato

- `GET /v1/admin/availability` → configuración persistida y jornadas semanales del artista autenticado.
- `PUT /v1/admin/availability` → reemplaza atómicamente settings y jornadas; no crea datos demo.
- Requiere cookie de sesión administrativa válida; sin cookie, revocada o expirada → `401 AUTH_INVALID`.
- Semana: `0=domingo ... 6=sábado`; horas locales `HH:mm`; zona IANA explícita.
- Los límites de validación rechazan weekday fuera de rango, horas inválidas, ventanas invertidas y parámetros no positivos.

## No incluido

- Bloqueos/excepciones CRUD, Calendar/freeBusy, endpoint público, disponibilidad calculada y UI Agenda.
- Credenciales, datos demo o valores de producción asumidos.

## Criterios de salida

- Solo el artista de la sesión puede leer/escribir su configuración.
- `PUT` usa una transacción y reemplaza la jornada completa sin dejar franjas antiguas.
- La respuesta no expone `passwordHash`, tokens ni datos de otro artista.
- Pruebas cubren 401, PUT/GET, validación y persistencia.

## Pasos

1. [x] Escribir pruebas e2e de guard, validación y round-trip PUT/GET.
2. [x] Implementar extracción de cookie y `AdminSessionGuard` reutilizable.
3. [x] Implementar DTO, servicio transaccional y controller de disponibilidad.
4. [x] Ejecutar formato, build, unit/e2e y lint.
5. Registrar avance; el motor público y bloques serán slices posteriores.
