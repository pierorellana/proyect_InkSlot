# InkSlot Admin Availability Blocks Plan

> SDD slice: contrato de bloqueos → pruebas e2e → CRUD scoped por artista → verificación → commit.

**Objetivo:** permitir al artista autenticado crear, listar y eliminar bloqueos internos que el motor de disponibilidad tratará como intervalos no disponibles.

**Fuentes:** `context/specs/04-availability-engine.md` RD-02/RD-03, `context/architecture/api-contracts.md`, `context/architecture/data-model.md` y `context/adr/ADR-002-booking-integrity-and-calendar.md`.

## Contrato

- `GET /v1/admin/blocks` lista bloqueos del artista autenticado ordenados por inicio.
- `POST /v1/admin/blocks` recibe `startAt`, `endAt` ISO-8601 UTC y `reason` opcional.
- `DELETE /v1/admin/blocks/:id` elimina únicamente un bloqueo perteneciente al artista autenticado.
- Intervalos invertidos o iguales → `400 INVALID_AVAILABILITY_BLOCK`; id fuera del alcance → `404 NOT_FOUND`.

## No incluido

- Excepciones que amplían jornada, Calendar externo, citas, disponibilidad pública o UI Agenda.

## Criterios de salida

- Guard administrativo y scoping por `artistId` en cada operación.
- La constraint PostgreSQL `start_at < end_at` sigue siendo la última barrera.
- Tests e2e cubren round-trip, validación, eliminación y aislamiento básico.

## Pasos

1. Añadir tests e2e de POST/GET/DELETE y rangos inválidos.
2. Implementar DTO, service y controller bajo `/admin/blocks`.
3. Ejecutar format, build, unit/e2e y lint.
4. Registrar avance; el endpoint público seguirá dependiendo de tokens y Calendar verificable.
