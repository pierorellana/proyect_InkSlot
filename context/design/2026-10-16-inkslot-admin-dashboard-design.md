# Diseño: dashboard administrativo e incidencias

**Fecha:** 2026-10-16  
**Slice:** T-017  
**Estado:** aprobado para planificación  
**Alcance:** dashboard administrativo, incidencias y filtros de Solicitudes/Citas

## Objetivo

Entregar un slice vertical para que el artista pueda abrir un Inicio administrativo con datos reales, consultar sus incidencias de sincronización y navegar entre Solicitudes y Citas conservando sus filtros. La fuente de verdad será PostgreSQL y la UI consumirá API NestJS mediante repositorios Flutter con Provider.

## Decisiones

- Implementar un endpoint agregado `GET /v1/admin/dashboard` protegido por `AdminSessionGuard`.
- Mantener las incidencias detalladas en `GET /v1/admin/sync-issues` y su retry en `POST /v1/admin/sync-issues/:id/retry`.
- Mantener los contratos existentes de solicitudes y citas; T-017 no modifica sus modelos Prisma ni añade migraciones.
- Filtrar cada consulta por el `artistId` de la sesión autenticada.
- Mantener los filtros en los `ChangeNotifier` de cada feature durante la sesión de la aplicación.
- Reutilizar los tokens, tipografías, iconos, componentes y animaciones visuales ya implementados; no añadir assets ni datos simulados.

## Contrato API

### `GET /v1/admin/dashboard`

Respuesta `200`:

```json
{
  "pendingRequests": 3,
  "upcomingAppointments": 5,
  "syncIssues": 1,
  "nextAppointments": [
    {
      "id": "uuid",
      "client": { "name": "Cliente" },
      "startAt": "2026-10-20T15:00:00.000Z",
      "endAt": "2026-10-20T18:00:00.000Z",
      "durationMinutes": 180,
      "status": "confirmed",
      "syncStatus": "synced"
    }
  ]
}
```

Reglas de proyección:

- `pendingRequests` cuenta `BookingRequestStatus.PENDING` del artista.
- `upcomingAppointments` cuenta citas `AppointmentStatus.CONFIRMED` con `startAt >= now` del artista.
- `syncIssues` cuenta `SyncIssueStatus.OPEN` asociado a citas del artista.
- `nextAppointments` devuelve las próximas cinco citas confirmadas ordenadas por `startAt ASC, id ASC`.
- Se proyectan únicamente los campos necesarios para Inicio: identidad de la cita, nombre del cliente, horario, duración y estados.
- No se exponen contacto, pago, tokens, hashes, credenciales, `calendarId`, `externalEventId` ni mensajes crudos de proveedores.
- Un artista sin datos recibe contadores `0` y `nextAppointments: []`.
- Los errores usan el envelope existente `{ "error": { "code": "...", "message": "..." } }`.

### Incidencias

`GET /v1/admin/sync-issues?status=open|resolved` conserva la respuesta existente y el alcance por artista. La vista puede ejecutar `POST /v1/admin/sync-issues/:id/retry`; tras un retry exitoso debe recargar la incidencia y el dashboard. `404` se presenta como incidencia no disponible y `401` termina la sesión local.

## Backend

Crear un módulo enfocado en dashboard con controller y service. El service realizará consultas Prisma read-only, en paralelo cuando sea seguro, y devolverá una proyección estable. El KPI de incidencias reutilizará la misma semántica de `SyncIssuesService` sin duplicar datos ni introducir un segundo mecanismo de retry. Se añadirán pruebas unitarias para conteos, orden, límite y aislamiento, y una prueba E2E con dos artistas, datos vacíos, incidencias y retry.

No se modifica el worker Calendar, el outbox, la disponibilidad, las acciones de citas ni la persistencia existente.

## Flutter

### Rutas y navegación

El `AdminShell` tendrá navegación responsive para:

- `/admin`: Inicio.
- `/admin/requests`: Solicitudes.
- `/admin/appointments`: Citas.
- `/admin/sync-issues`: Incidencias.

`/admin` dejará de redirigir automáticamente a Solicitudes. Los controllers de Solicitudes y Citas conservarán su filtro mientras permanezcan vivos durante la sesión. Las tarjetas KPI de Inicio serán enlaces a la vista correspondiente con el filtro inicial apropiado.

### Inicio

Crear modelos, repositorio y `ChangeNotifier` de dashboard. La pantalla mostrará:

- encabezado del espacio de trabajo;
- KPI de solicitudes pendientes, próximas citas e incidencias abiertas;
- lista de próximas citas;
- enlaces seguros a Solicitudes, Citas e Incidencias.

Estados obligatorios: `loading`, `loaded`, `empty` cuando no hay próximas citas, `error` con retry y sesión expirada. Los contadores se consideran válidos aunque la lista de próximas citas esté vacía.

### Citas e incidencias

La lista de Citas consumirá el endpoint de T-016, tendrá filtros por `confirmed`, `completed`, `cancelled` y `no_show`, y conservará el estado al navegar. La vista de Incidencias consumirá el endpoint existente, alternará abiertas/resueltas, permitirá retry y mostrará el estado actualizado sin datos sensibles. Ambas vistas tendrán loading, empty, error y retry.

Las pantallas reutilizarán `InkSlotTokens`, `InkSlotPage`, `InkSlotMonoLabel`, `InkSlotPrimaryButton`, tipografías locales y las transiciones existentes. Los objetivos táctiles serán de al menos 44 px y se respetará `MediaQuery.disableAnimations`.

## Seguridad y errores

- Todo endpoint admin usa `AdminSessionGuard` y filtra por `artistId`.
- El cliente no persiste respuestas del dashboard ni tokens de sesión en local storage.
- Los errores de red conservan filtros y ofrecen retry.
- `401 AUTH_INVALID` limpia la sesión mediante `AdminSessionController` y redirige a `/admin/login`.
- El retry no crea una operación distinta: reactiva el outbox existente y deja que el worker actualice la incidencia.

## Pruebas y verificación

### API

- unitarias de dashboard service y controller;
- aislamiento entre artistas;
- conteo de solicitudes, citas e incidencias;
- orden y límite de próximas citas;
- dashboard vacío;
- E2E de dashboard, incidencias y retry;
- `npm test -- --runInBand --watchman=false`;
- `npm run test:e2e -- --runInBand --watchman=false`;
- `npm run build`;
- `git diff --check`.

### Flutter

- serialización y repositorio del dashboard;
- controllers para loading, loaded, empty, error, retry y `401`;
- widget tests de Inicio, filtros de Citas e Incidencias;
- navegación y persistencia de filtros;
- `fvm dart format lib test`;
- `fvm flutter analyze`;
- `fvm flutter test`;
- `fvm flutter build web`.

## Fuera de alcance

- Agenda visual, configuración de disponibilidad y conexión Calendar.
- Edición o acciones de detalle de Citas desde Flutter.
- Nuevas migraciones Prisma, Docker, Redis o colas externas.
- Cambios al prototipo HTML/ZIP o al PDF de documentación.
- Auditoría final de paridad de las 38 capturas y accesibilidad completa de T-019.

## Referencias

- `context/tasks/backlog.md` — T-017.
- `context/specs/07-admin-dashboard-and-config.md`.
- `context/design/2026-10-16-inkslot-admin-requests-design.md`.
- `context/design/2026-10-16-inkslot-appointments-actions-design.md`.
- `context/architecture/api-contracts.md`.
- `context/architecture/solution.md`.
- `context/adr/ADR-002-booking-integrity-and-calendar.md`.
- `context/adr/ADR-004-design-fidelity-and-motion.md`.
