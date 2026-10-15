# Booking Requests and Public Tokens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use the project SDD conventions in `context/00-governance/AGENTS.md` and implement one task at a time with a focused commit.

**Goal:** Deliver artist-scoped booking requests, secure expiring public links, administrative lifecycle actions, and a minimal public reservation summary.

**Architecture:** Add a NestJS `requests` module around the existing Prisma `Client`, `BookingRequest`, `BookingToken`, and `AuditLog` models. A pure token helper generates and hashes opaque secrets; `BookingRequestsService` owns artist scoping, transactions, lifecycle rules, cursor pagination, and safe responses; the controller exposes admin and public routes. PostgreSQL remains the source of truth, and raw tokens are returned only when creating or renewing a link.

**Tech Stack:** NestJS 11, TypeScript, Prisma 6.19, PostgreSQL local, `class-validator`, `class-transformer`, Node `crypto`, Jest, Supertest.

## Global Constraints

- Keep workspace roots limited to `app`, `api`, and `context`.
- Use local PostgreSQL and Prisma migrations; do not add Docker or external infrastructure.
- Preserve `Flutter Web + Provider`, `NestJS + TypeScript`, and `PostgreSQL`; this slice changes backend only.
- Every admin query must scope by the authenticated `artistId`; never trust an artist ID from the request body.
- `Client` must be owned by an artist; an existing client from another artist must behave as not found.
- Generate public tokens with `crypto.randomBytes(32).toString('base64url')`; persist only SHA-256 hex hashes.
- Never log, audit, list, detail, or return raw tokens outside create/renew responses.
- Use the existing `/v1` prefix, `AdminSessionGuard`, global `ValidationPipe`, throttler, and safe error envelope.
- Use Prisma interactive transactions for create, renew, revoke, close, and expiration transitions.
- Default token TTL is 48 hours; accepted custom TTL is an integer from 1 to 720 hours.
- Public responses contain no client contact, notes, IDs, hashes, deposits, or data from another client.
- Do not implement public availability, confirmation, appointments, idempotency, outbox, event sync, or Flutter screens in this plan.
- Every task ends with focused verification and a small Conventional Commit.

## File Map

Create:

- `api/src/requests/requests.constants.ts` — default TTL and page size.
- `api/src/requests/booking-token.ts` — token generation, hashing, and cursor encoding helpers.
- `api/src/requests/booking-token.spec.ts` — token entropy, hash, and cursor tests.
- `api/src/requests/requests.dto.ts` — admin create/filter DTOs and nested client/restriction DTOs.
- `api/src/requests/requests.service.ts` — admin lifecycle and public resolution use cases.
- `api/src/requests/requests.service.spec.ts` — focused service tests with Prisma/clock mocks.
- `api/src/requests/requests.controller.ts` — guarded admin routes and unguarded public route.
- `api/src/requests/requests.module.ts` — module wiring.
- `api/test/requests.e2e-spec.ts` — local PostgreSQL endpoint and isolation coverage.
- `api/prisma/migrations/20261015220000_client_artist_scope/migration.sql` — ownership constraint and index.

Modify:

- `api/prisma/schema.prisma` — `Artist.clients`, `Client.artistId`, relation, and index.
- `api/src/app.module.ts` — import `RequestsModule`.
- `api/test/persistence-foundation.e2e-spec.ts` — provide `artistId` when creating clients.
- `context/tasks/backlog.md` — record T-010 progress.

## Task 1: Add artist-scoped clients and token primitives

**Files:**

- Modify: `api/prisma/schema.prisma`
- Create: `api/prisma/migrations/20261015220000_client_artist_scope/migration.sql`
- Modify: `api/test/persistence-foundation.e2e-spec.ts`
- Create: `api/src/requests/requests.constants.ts`
- Create: `api/src/requests/booking-token.ts`
- Create: `api/src/requests/booking-token.spec.ts`

**Interfaces:**

```ts
export const DEFAULT_BOOKING_TOKEN_TTL_HOURS = 48;
export const MAX_BOOKING_TOKEN_TTL_HOURS = 720;
export const BOOKING_REQUEST_PAGE_SIZE = 20;

export type GeneratedBookingToken = {
  token: string;
  tokenHash: string;
};

export function generateBookingToken(): GeneratedBookingToken;
export function hashBookingToken(token: string): string;
export function encodeBookingCursor(input: {
  createdAt: Date;
  id: string;
}): string;
export function decodeBookingCursor(cursor: string): {
  createdAt: Date;
  id: string;
};
```

- [ ] **Step 1: Extend Prisma ownership relations**

Add `clients Client[]` to the existing `Artist` model and replace the existing `Client` model with:

```prisma
model Client {
  id              String           @id @default(uuid()) @db.Uuid
  artistId        String           @map("artist_id") @db.Uuid
  name            String           @db.VarChar(120)
  email           String?          @db.VarChar(320)
  phone           String?          @db.VarChar(32)
  createdAt       DateTime         @default(now()) @map("created_at") @db.Timestamptz(6)
  artist          Artist           @relation(fields: [artistId], references: [id], onDelete: Restrict)
  bookingRequests BookingRequest[]

  @@index([artistId, createdAt])
  @@map("clients")
}
```

Do not change the existing `BookingRequest.clientId` relation or token columns.

- [ ] **Step 2: Create an additive migration and inspect it**

From `api`, create a migration without applying it, then rename the generated directory to the fixed migration path below before applying it:

```bash
npx prisma migrate dev --create-only --name client_artist_scope
# Rename the generated `*_client_artist_scope` directory to
# `20261015220000_client_artist_scope`.
```

Replace the generated SQL with an additive migration that adds the nullable column, refuses to continue if existing rows cannot be assigned safely, then makes it required, adds the foreign key and index:

```sql
ALTER TABLE "clients" ADD COLUMN "artist_id" UUID;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM "clients" WHERE "artist_id" IS NULL) THEN
    RAISE EXCEPTION 'clients.artist_id requires an explicit owner before migration';
  END IF;
END $$;

ALTER TABLE "clients" ALTER COLUMN "artist_id" SET NOT NULL;
ALTER TABLE "clients"
  ADD CONSTRAINT "clients_artist_id_fkey"
  FOREIGN KEY ("artist_id") REFERENCES "artists"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX "clients_artist_id_created_at_idx" ON "clients"("artist_id", "created_at");
```

Apply and generate the client:

```bash
npx prisma migrate deploy
npx prisma generate
npx prisma migrate status
```

Expected: the new migration is applied, no migration drops a column or constraint, and status reports the database up to date. The local test database is expected to contain no unowned clients; if rows exist, stop with the explicit migration error instead of assigning them to an arbitrary artist.

- [ ] **Step 3: Update the persistence fixture**

In `api/test/persistence-foundation.e2e-spec.ts`, change both client creates to include the owning artist:

```ts
const client = await prisma.client.create({
  data: {
    artistId: artist.id,
    name: 'Cliente de prueba',
    phone: '+593000000000',
  },
});
```

Keep cleanup scoped by the created client IDs or artist ID. Add an assertion that a client loaded through the request has the same `artistId`.

- [ ] **Step 4: Implement token and cursor helpers**

Create `booking-token.ts` with these semantics:

```ts
import { createHash, randomBytes } from 'node:crypto';

export function generateBookingToken(): GeneratedBookingToken {
  const token = randomBytes(32).toString('base64url');
  return { token, tokenHash: hashBookingToken(token) };
}

export function hashBookingToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}
```

Encode a cursor as base64url JSON containing only the ISO timestamp and UUID. Decode must reject malformed base64, non-UUID IDs, invalid dates, and unexpected fields with `BadRequestException` using `{ error: { code: 'BAD_REQUEST', message: 'El cursor no es válido' } }`. Never include the cursor contents in the error.

- [ ] **Step 5: Write and run token tests**

Cover token length/URL safety, distinct values for repeated generation, deterministic 64-character hashes, round-trip cursor encoding, malformed cursor rejection, and absence of token plaintext in hash/cursor values.

Run:

```bash
npm test -- --runInBand --watchman=false src/requests/booking-token.spec.ts
npx prettier --check src/requests/booking-token.ts src/requests/booking-token.spec.ts
```

Expected: tests pass after implementation and formatting is clean. Commit:

```bash
git add api/prisma/schema.prisma api/prisma/migrations api/test/persistence-foundation.e2e-spec.ts api/src/requests/requests.constants.ts api/src/requests/booking-token.ts api/src/requests/booking-token.spec.ts
git commit -m "feat(api): scope clients and add booking tokens"
```

## Task 2: Implement administrative request lifecycle

**Files:**

- Create: `api/src/requests/requests.dto.ts`
- Create: `api/src/requests/requests.service.ts`
- Create: `api/src/requests/requests.service.spec.ts`
- Create: `api/src/requests/requests.controller.ts`
- Create: `api/src/requests/requests.module.ts`
- Modify: `api/src/app.module.ts`

**Interfaces:**

```ts
export type BookingRequestStatusApi =
  | 'pending'
  | 'booked'
  | 'cancelled'
  | 'expired'
  | 'closed';

export type CreateBookingRequestResult = {
  request: BookingRequestAdminResponse;
  link: { path: string; expiresAt: string };
};

export type BookingRequestListResponse = {
  items: BookingRequestAdminResponse[];
  nextCursor: string | null;
};

export type PublicReservationResponse = {
  status: 'pending' | 'booked';
  artist: { displayName: string };
  durationMinutes: number;
  timezone: string;
  restrictions: BookingRestrictionsResponse;
  expiresAt: string;
};
```

- [ ] **Step 1: Define validated DTOs**

Create nested DTOs for inline clients, allowed windows, create requests, status filters, and token actions. Use `@ValidateNested`, `@Type`, `@IsOptional`, `@IsString`, `@IsEmail`, `@IsInt`, `@Min`, `@Max`, `@IsBoolean`, `@IsDateString`, `@IsArray`, `@ArrayUnique`, and a strict `HH:mm` regex. DTO validation handles shape; service validation handles mutual exclusivity and cross-field ordering.

The create DTO must expose `clientId?: string`, `client?: InlineClientDto`, `depositVerified: boolean`, `durationMinutes`, `minDate?`, `maxDate?`, `allowedWeekdays?`, `allowedWindows?`, and `tokenTtlHours?`. The status query accepts only the five lowercase API statuses and `cursor?`.

- [ ] **Step 2: Write service unit tests before implementation**

Mock Prisma delegates, the clock, and token helper output. Cover:

```ts
it('creates an inline client, request, token hash, and audit row atomically', async () => {
  await service.create('artist-a', {
    client: { name: 'Cliente', phone: '+593000000000' },
    depositVerified: true,
    durationMinutes: 180,
  });

  expect(tx.client.create).toHaveBeenCalledWith({
    data: { artistId: 'artist-a', name: 'Cliente', email: null, phone: '+593000000000' },
  });
  expect(tx.bookingToken.create).toHaveBeenCalledWith(
    expect.objectContaining({ data: expect.objectContaining({ tokenHash: expect.any(String) }) }),
  );
  expect(tx.auditLog.create).toHaveBeenCalledWith(
    expect.objectContaining({
      data: expect.objectContaining({
        actorId: 'artist-a',
        entityType: 'booking_request',
        action: 'created',
      }),
    }),
  );
});
```

Also cover existing-client ownership, deposit false (`DEPOSIT_NOT_VERIFIED`), invalid restrictions (`INVALID_RESTRICTIONS`), invalid TTL, request scoping, renew rotation, idempotent revoke/close, booked conflicts, and that raw tokens never reach Prisma/audit data.

- [ ] **Step 3: Implement create and response mapping**

In `BookingRequestsService.create`, validate exactly one client source, deposit, dates, weekdays, windows, duration, and TTL. Use `prisma.$transaction(async (tx) => ...)` to:

1. Create an inline client with `artistId`, or load an existing client with `{ id: clientId, artistId }` and return `404 NOT_FOUND` if absent.
2. Generate the raw/hash token in memory.
3. Create `BookingRequest` with `PENDING`, restrictions JSON, and deposit verification fields.
4. Create `BookingToken` with hash and UTC expiry.
5. Create safe `AuditLog` row.
6. Return the mapped admin request and raw path `/r/${token}` after the transaction succeeds.

The raw token must not be placed in Prisma data, audit changes, logs, or exceptions.

- [ ] **Step 4: Implement list/detail and cursor pagination**

List with `where: { artistId, status? }`, order by `createdAt desc, id desc`, take 21, and a cursor predicate derived from `(createdAt,id)`. Return the first 20 and encode the next item position. Include only the artist-owned client and a derived current-link status; never include the raw token.

Detail must use `findFirst({ where: { id, artistId } })`; missing or cross-artist IDs return `404 NOT_FOUND`. Include audit entries only for the same request entity.

- [ ] **Step 5: Implement renew, revoke, and close transactions**

Renew must lock the request by updating it inside the transaction, reject `BOOKED` with `409 ALREADY_BOOKED`, reject terminal states with safe `400`, revoke prior active tokens, create one new hash with the configured TTL, set `EXPIRED` back to `PENDING`, and audit `token_renewed`.

Revoke changes `PENDING`/`EXPIRED` to `CANCELLED`, revokes non-revoked tokens, and audits `revoked`. Close changes `PENDING`/`EXPIRED` to `CLOSED`, revokes non-revoked tokens, and audits `closed`. Repeating the same action is idempotent and does not create a second audit row or token.

- [ ] **Step 6: Wire guarded routes and module**

Use:

```ts
@Controller('admin/booking-requests')
@UseGuards(AdminSessionGuard)
```

Implement `POST`, `GET`, `GET :id`, and `POST :id/renew|revoke|close`, passing `request.user.id` to every service method. Import `PrismaModule` and `AuthModule` through the existing global/module pattern, register `RequestsModule` in `AppModule`, and keep the public controller method unguarded.

- [ ] **Step 7: Run focused service tests and commit**

Run:

```bash
npm test -- --runInBand --watchman=false src/requests/requests.service.spec.ts
npm run build
```

Expected: focused request service tests and build pass. Commit:

```bash
git add api/src/requests api/src/app.module.ts
git commit -m "feat(api): add booking request lifecycle"
```

## Task 3: Implement public token resolution and expiration behavior

**Files:**

- Modify: `api/src/requests/requests.service.ts`
- Modify: `api/src/requests/requests.controller.ts`
- Modify: `api/src/requests/requests.service.spec.ts`

**Interfaces:**

```ts
resolvePublic(token: string): Promise<PublicReservationResponse>;
```

- [ ] **Step 1: Write public resolution tests**

Cover an active token returning only safe summary data, a `BOOKED` request returning `status: booked`, unknown hash returning `404 NOT_FOUND`, expired token returning `410 TOKEN_EXPIRED`, revoked token returning `410 TOKEN_REVOKED`, cancelled/closed request returning `410 TOKEN_REVOKED`, and expired-token transition to `EXPIRED` only when no newer active token exists.

Assert that response serialization never contains client email/phone/name, artist ID, request ID, token hash, token plaintext, deposit fields, notes, or audit details.

- [ ] **Step 2: Implement hash lookup and safe projection**

Hash the route token with `hashBookingToken(token)`, load the token with its request, artist, client only as needed, and `studioSettings`. Use `findFirst`/`include` with `request.artist.studioSettings` and no public client fields in the mapped response. If the artist has no `StudioSettings`, throw `503 SERVICE_UNAVAILABLE` because the next availability slice cannot safely interpret dates without an IANA timezone.

Apply link/request state checks in this order: missing hash, revoked/terminal, expired, then active/booked. The raw token remains only in the request stack and is never copied into the response.

- [ ] **Step 3: Implement expiration transition transaction**

For an expired token, use a Prisma transaction to check whether another token for the same request has `revokedAt = null` and `expiresAt > now`. If none exists and the request is `PENDING`, update it to `EXPIRED`; then return `410 TOKEN_EXPIRED`. Do not revoke or alter the historical token row.

- [ ] **Step 4: Add the public controller route**

Add:

```ts
@Get('public/reservations/:token')
resolvePublic(@Param('token') token: string) {
  return this.requests.resolvePublic(token);
}
```

Keep it outside the admin guard and ensure the global throttler applies. Do not add token values to logs or analytics.

- [ ] **Step 5: Run public tests and commit**

Run:

```bash
npm test -- --runInBand --watchman=false src/requests/requests.service.spec.ts
npm run build
```

Expected: public resolution tests pass and the API builds. Commit:

```bash
git add api/src/requests
git commit -m "feat(api): resolve public booking links"
```

## Task 4: Verify HTTP contracts, persistence, and SDD evidence

**Files:**

- Create: `api/test/requests.e2e-spec.ts`
- Modify: `context/tasks/backlog.md`

- [ ] **Step 1: Add E2E setup and artist isolation tests**

Use the existing Nest E2E pattern with local PostgreSQL, two artists, admin cookies, and a fake clock where necessary. Verify:

- admin without cookie receives `401 AUTH_INVALID`;
- inline create persists artist-owned client, request, token hash, deposit trace, and audit;
- existing client from the same artist works;
- client from another artist returns `404`;
- `depositVerified: false` returns `422 DEPOSIT_NOT_VERIFIED`;
- list/detail never return raw token or token hash;
- public GET works without login and returns the minimal projection.

- [ ] **Step 2: Add lifecycle and error tests**

Verify renewal invalidates the old URL with `410 TOKEN_REVOKED`, returns a different token, keeps one active token, and creates one audit row. Verify revoke/close are idempotent and public access returns `410`. Verify a manually expired token returns `410 TOKEN_EXPIRED` and updates request status only when no active replacement exists. Verify invalid cursor, invalid restrictions, unknown request, and booked action responses.

- [ ] **Step 3: Update backlog evidence**

Change T-010 in `context/tasks/backlog.md` to record completed client ownership, admin request lifecycle, secure token rotation, public summary, audit, and PostgreSQL E2E coverage. Leave admin Flutter UI, public availability, and confirmation explicitly pending.

- [ ] **Step 4: Run complete API verification**

Run from `api`:

```bash
NODE_OPTIONS=--max-old-space-size=4096 npm test -- --runInBand --watchman=false
NODE_OPTIONS=--max-old-space-size=4096 npm run test:e2e -- --runInBand --watchman=false
NODE_OPTIONS=--max-old-space-size=4096 npm run build
```

Run lint serially with enough heap; record any pre-existing errors without changing unrelated slices:

```bash
NODE_OPTIONS=--max-old-space-size=4096 npm run lint
```

Expected: tests, E2E, and build pass. E2E uses only local PostgreSQL and no external messaging or Google call.

- [ ] **Step 5: Commit integration evidence**

```bash
git add api/test/requests.e2e-spec.ts context/tasks/backlog.md
git commit -m "test(api): verify booking request contracts"
```

## Self-review checklist

- Spec coverage: client ownership, deposit verification, request lifecycle, token hash/TTL/rotation, public safe projection, audit, cursor, and HTTP error paths are covered by Tasks 1–4.
- Placeholder scan: this plan contains no `TBD`, `TODO`, or unspecified implementation step.
- Type consistency: `GeneratedBookingToken`, `BookingRequestStatusApi`, `CreateBookingRequestResult`, `BookingRequestListResponse`, and `PublicReservationResponse` are used consistently.
- Scope check: this plan stops before public availability, confirmation, appointments, Calendar orchestration, outbox, and Flutter UI.
