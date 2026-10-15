# InkSlot Persistence Foundation Implementation Plan

> SDD slice: especificación → prueba de integración → Prisma/migración SQL → verificación → commit enfocado.

**Objetivo:** convertir el modelo lógico aprobado en un contrato persistente local para auth, disponibilidad, solicitudes, citas y sincronización, sin activar todavía flujos que aún no tienen caso de uso.

**Fuentes:** `context/design/2026-10-15-inkslot-platform-design.md`, `context/architecture/data-model.md`, `context/specs/04-availability-engine.md`, `context/adr/ADR-002-booking-integrity-and-calendar.md`, `context/adr/ADR-003-auth-and-public-tokens.md`.

## Alcance

- Extender `Artist` para soportar credenciales administrativas hasheadas.
- Modelar configuración de estudio, jornada, bloqueos, clientes, solicitudes, tokens, citas, Calendar, outbox, incidencias, auditoría e idempotencia.
- Mantener UTC en `timestamptz` y fechas de restricciones como `date`; la zona IANA vive en `studio_settings`.
- Habilitar `btree_gist` y crear mediante SQL la columna generada `tstzrange` y la exclusión de solapamientos de citas por artista.
- Verificar relaciones, restricciones de rango y la carrera básica de dos citas superpuestas contra PostgreSQL local.

## No incluido

- Login, cookies, guards, Argon2id y sesiones.
- Motor de disponibilidad, Calendar real, worker/outbox y endpoints de negocio.
- Datos demo de horarios o credenciales sembradas.
- Docker/Compose o cambios fuera de `app/`, `api/` y `context/`.

## Criterios de salida

- `prisma validate`, `prisma migrate status`, build Nest y tests de integración pasan.
- La migración es reproducible desde una base vacía y usa `SHADOW_DATABASE_URL` local.
- Una segunda cita confirmada/completada/no-show que se solapa es rechazada por PostgreSQL; una cancelada no bloquea el rango.
- No se guardan tokens públicos en claro: solo existe `booking_tokens.token_hash`.
- Se documentan las nuevas tablas y el alcance restante en el backlog.

## Pasos

1. [x] Escribir el test de integración de persistencia y conflicto de rangos.
2. [x] Actualizar `schema.prisma` con enums, relaciones y tipos PostgreSQL.
3. [x] Generar la migración Prisma, añadir SQL explícito para `btree_gist`, `tstzrange` y `EXCLUDE`.
4. [x] Ejecutar migración, generación de cliente, formato, build y tests locales.
5. Registrar evidencia y crear un commit enfocado; el slice siguiente implementará auth sobre `Artist.password_hash`.
