# InkSlot local demo seed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crear un seed Prisma idempotente para que `demo-token` resuelva una reserva pública válida en PostgreSQL local.

**Architecture:** El seed vive en `api/prisma/seed.ts` y usa Prisma Client dentro de una transacción. Identifica el conjunto demo con claves naturales dedicadas, persiste el token solo como hash SHA-256 y restablece una eventual cita creada por pruebas únicamente para esa solicitud. El seed no se invoca desde NestJS.

**Tech Stack:** Prisma 6.19.x, Prisma Client, TypeScript/ts-node, PostgreSQL local, NestJS API existente.

## Global Constraints

- Mantener PostgreSQL local; no añadir Docker.
- Mantener el token público opaco en persistencia: nunca guardar `demo-token` en `BookingToken.tokenHash` sin hash.
- No crear ni modificar una conexión OAuth de Google Calendar.
- Mantener el conjunto demo aislado por `demo@inkslot.local` y `demo-local-seed`.
- Ejecutar y verificar con Node 24.5.0 mediante FVM/entorno local existente y Prisma 6.

### Task 1: Documentar y conectar el comando de seed

**Files:**
- Create: `api/prisma/seed.ts`
- Modify: `api/package.json`
- Modify: `context/manifest.json`
- Modify: `context/tasks/backlog.md`
- Create: `context/design/2026-10-16-inkslot-local-demo-seed-design.md`
- Create: `context/plans/2026-10-16-inkslot-local-demo-seed-plan.md`

**Interfaces:**
- Consumes: `DATABASE_URL`, Prisma schema existente y `hashBookingToken` de `api/src/requests/booking-token.ts`.
- Produces: `npm run db:seed`, que ejecuta `prisma db seed` y crea el fixture `demo-token`.

- [x] **Step 1: Añadir la configuración Prisma al package manifest**

En `api/package.json`, agregar el script:

```json
"db:seed": "prisma db seed"
```

y la configuración:

```json
"prisma": {
  "seed": "ts-node --transpile-only prisma/seed.ts"
}
```

- [x] **Step 2: Implementar el seed transaccional idempotente**

En `api/prisma/seed.ts`, usar `PrismaClient`, `argon2`, `BookingRequestStatus`, `Prisma` y `hashBookingToken`. Crear el artista por `email`, configurar el estudio, reemplazar sus seis ventanas semanales, buscar/crear el cliente por artista y correo, buscar/crear la solicitud por artista/cliente/referencia, eliminar una eventual cita demo y sus outbox/auditorías, restablecer `PENDING`, reemplazar sus tokens y crear:

```ts
{
  tokenHash: hashBookingToken('demo-token'),
  expiresAt: new Date('2099-12-31T23:59:59.000Z'),
  revokedAt: null,
  consumedAt: null,
}
```

El `finally` debe desconectar Prisma y el `catch` debe escribir el error y terminar con código distinto de cero.

- [x] **Step 3: Ejecutar el seed dos veces**

Run from `api`:

```bash
PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run db:seed
PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run db:seed
```

Expected: ambas ejecuciones terminan correctamente y la segunda no crea duplicados.

- [x] **Step 4: Commit del fixture**

```bash
git add api/package.json api/prisma/seed.ts context/manifest.json context/tasks/backlog.md context/design/2026-10-16-inkslot-local-demo-seed-design.md context/plans/2026-10-16-inkslot-local-demo-seed-plan.md
git commit -m "feat(api): add local demo reservation seed"
```

### Task 2: Validar contrato público y regresiones

**Files:**
- Test runtime: PostgreSQL local y API NestJS existente; no crear endpoints nuevos.

**Interfaces:**
- Consumes: `GET /v1/public/reservations/demo-token`.
- Produces: respuesta pública `200` y disponibilidad del fixture para Flutter.

- [x] **Step 1: Comprobar el endpoint público**

```bash
curl -i http://127.0.0.1:3000/v1/public/reservations/demo-token
```

Expected: `HTTP/1.1 200 OK` y JSON con `status: "pending"`, `artist.displayName: "Dodogio"`, `durationMinutes: 60` y `timezone: "America/Guayaquil"`.

- [x] **Step 2: Ejecutar pruebas API**

```bash
PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false
PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
```

Expected: suites y build existentes pasan sin cambios de contrato.

- [x] **Step 3: Regenerar la web con la API configurada**

```bash
fvm flutter build web --dart-define=API_BASE_URL=https://9hqbzkgw-3000.use.devtunnels.ms/v1
```

Expected: `✓ Built build/web`.

- [x] **Step 4: Commit de verificación si se añaden pruebas/documentación**

```bash
git status --short
```

Expected: no cambios no relacionados y el fixture queda documentado en el backlog.

## Resultado de ejecución — 2026-10-16

- `npm run db:seed` ejecutado dos veces con Node 24.5.0; ambas ejecuciones conservaron los mismos IDs y no duplicaron el fixture.
- `GET https://9hqbzkgw-3000.use.devtunnels.ms/v1/public/reservations/demo-token` devuelve `200` con estado `pending`, `Dodogio`, 60 minutos y zona `America/Guayaquil`.
- `npm test -- --runInBand --watchman=false`: 329 pruebas y 18 suites aprobadas.
- `npm run build`: compilación NestJS aprobada.
- El build Flutter Web existente ya apunta al API del túnel y se mantiene sin cambios porque el seed no modifica el bundle.
