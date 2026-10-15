# Calendar OAuth Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use the project SDD conventions in `context/00-governance/AGENTS.md` and implement one task at a time with a focused commit.

**Goal:** Connect an authenticated InkSlot artist to the dedicated Google Calendar `InkSlot` through a secure, testable OAuth flow.

**Architecture:** NestJS owns the OAuth Authorization Code flow. A `CalendarProvider` interface isolates Google from the application, while Prisma stores the encrypted refresh token, selected calendar metadata, connection status, and one-time OAuth states. The callback returns safe JSON in this local slice; no token is exposed to Flutter.

**Tech Stack:** NestJS 11, TypeScript, Prisma 6, PostgreSQL, `googleapis`, Jest, Supertest, Argon2 sessions, Node `crypto` AES-256-GCM.

## Global Constraints

- Keep workspace roots limited to `app`, `api`, and `context`.
- Use local PostgreSQL and Prisma migrations; do not add Docker.
- Keep Google client secrets, refresh tokens, encryption keys, and authorization codes out of Git, logs, HTTP responses, and Flutter.
- Use the existing `/v1` prefix, `AdminSessionGuard`, global validation, and safe error envelope.
- Use only `calendar.freebusy`, `calendar.events`, and `calendar.calendarlist.readonly` scopes.
- Select a unique calendar whose configured summary is `InkSlot`; never silently fall back to `primary`.
- OAuth state expires after 10 minutes and can be consumed only once.
- Preserve `context/specs/06-google-calendar.md`, `context/adr/ADR-002-booking-integrity-and-calendar.md`, and `context/design/2026-10-15-inkslot-calendar-oauth-design.md`.
- Every task ends with focused tests and a small Conventional Commit.

## File Map

Create:

- `api/src/calendar/calendar.constants.ts` — provider token, safe status values, OAuth lifetime.
- `api/src/calendar/calendar.config.ts` — optional runtime configuration and scope parsing.
- `api/src/calendar/calendar.config.spec.ts` — configuration tests.
- `api/src/calendar/calendar.crypto.ts` — AES-256-GCM encryption/decryption.
- `api/src/calendar/calendar.crypto.spec.ts` — crypto tests.
- `api/src/calendar/calendar.provider.ts` — provider interface and value types.
- `api/src/calendar/google-calendar.provider.ts` — `googleapis` implementation.
- `api/src/calendar/calendar.state.service.ts` — hashed, one-time OAuth state lifecycle.
- `api/src/calendar/calendar.state.service.spec.ts` — state lifecycle tests.
- `api/src/calendar/calendar.service.ts` — connection use cases and safe status mapping.
- `api/src/calendar/calendar.controller.ts` — admin OAuth/status routes.
- `api/src/calendar/calendar.module.ts` — module wiring.
- `api/test/calendar-persistence.e2e-spec.ts` — persistence coverage.
- `api/test/calendar.e2e-spec.ts` — endpoint coverage.

Modify:

- `api/package.json` and `api/package-lock.json` — add `googleapis`.
- `api/.env.example` — document non-secret Calendar variables.
- `api/prisma/schema.prisma` — connection metadata, `NEEDS_RECONNECT`, and OAuth state.
- `api/src/app.module.ts` — import `CalendarModule`.
- `context/local-development.md` — document local OAuth verification.
- `context/tasks/backlog.md` — record the completed OAuth slice.

## Task 1: Add optional Calendar configuration and Google client dependency

**Files:**

- Modify: `api/package.json`
- Modify: `api/package-lock.json`
- Modify: `api/.env.example`
- Create: `api/src/calendar/calendar.constants.ts`
- Create: `api/src/calendar/calendar.config.ts`
- Test: `api/src/calendar/calendar.config.spec.ts`

**Interfaces:**

- `CalendarConfig` exposes `configured`, `clientId`, `clientSecret`, `redirectUri`, `calendarName`, `scopes`, and `tokenEncryptionKey`.
- `CALENDAR_PROVIDER` is the dependency injection token used by later tasks.

- [ ] **Step 1: Add the official Node client**

Run from `api`:

    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm install googleapis

Expected: `googleapis` appears in `dependencies` and `package-lock.json` changes without unrelated package upgrades.

- [ ] **Step 2: Write configuration tests**

Create tests for:

    describe('CalendarConfig', () => {
      it('is unconfigured when Google values are absent', () => {
        expect(readCalendarConfig({} as NodeJS.ProcessEnv).configured).toBe(false);
      });

      it('parses scopes and validates a 32-byte AES key', () => {
        const config = readCalendarConfig({
          GOOGLE_CLIENT_ID: 'client-id',
          GOOGLE_CLIENT_SECRET: 'client-secret',
          GOOGLE_REDIRECT_URI: 'http://localhost:3000/v1/admin/calendar/callback',
          GOOGLE_CALENDAR_NAME: 'InkSlot',
          GOOGLE_CALENDAR_SCOPES: 'scope-a, scope-b',
          GOOGLE_TOKEN_ENCRYPTION_KEY: Buffer.alloc(32).toString('base64'),
        });

        expect(config.configured).toBe(true);
        expect(config.calendarName).toBe('InkSlot');
        expect(config.scopes).toEqual(['scope-a', 'scope-b']);
        expect(config.tokenEncryptionKey).toHaveLength(32);
      });
    });

- [ ] **Step 3: Implement optional configuration**

Implement `readCalendarConfig(env)` so missing Calendar variables produce `configured: false`, while a present encryption key must decode to exactly 32 bytes. Default `GOOGLE_CALENDAR_NAME` to `InkSlot`. Never log values.

Use:

    export const CALENDAR_PROVIDER = Symbol('CALENDAR_PROVIDER');
    export const CALENDAR_OAUTH_STATE_TTL_MS = 10 * 60 * 1000;

- [ ] **Step 4: Document local variables**

Add to `api/.env.example`:

    GOOGLE_PROJECT_ID=
    GOOGLE_CLIENT_ID=
    GOOGLE_CLIENT_SECRET=
    GOOGLE_REDIRECT_URI=http://localhost:3000/v1/admin/calendar/callback
    GOOGLE_CALENDAR_NAME=InkSlot
    GOOGLE_CALENDAR_SCOPES=https://www.googleapis.com/auth/calendar.freebusy,https://www.googleapis.com/auth/calendar.events,https://www.googleapis.com/auth/calendar.calendarlist.readonly
    GOOGLE_TOKEN_ENCRYPTION_KEY=
    CALENDAR_TIMEZONE=America/Guayaquil

- [ ] **Step 5: Test and commit**

Run:

    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/calendar/calendar.config.spec.ts

Expected: PASS. Commit:

    git add api/package.json api/package-lock.json api/.env.example api/src/calendar
    git commit -m "feat(api): add calendar oauth configuration"

## Task 2: Persist connection metadata and one-time OAuth state

**Files:**

- Modify: `api/prisma/schema.prisma`
- Create: Prisma migration named `calendar_oauth_connection`
- Test: `api/test/calendar-persistence.e2e-spec.ts`

**Interfaces:**

- `CalendarConnectionStatus` gains `NEEDS_RECONNECT`.
- `CalendarConnection` gains nullable `calendarName`.
- `CalendarOAuthState` exposes `id`, `artistId`, `stateHash`, `expiresAt`, `consumedAt`, and `createdAt`.

- [ ] **Step 1: Extend the Prisma schema**

Add `NEEDS_RECONNECT`, add nullable `calendarName` to `CalendarConnection`, and add:

    model CalendarOAuthState {
      id         String    @id @default(uuid()) @db.Uuid
      artistId   String    @map("artist_id") @db.Uuid
      stateHash  String    @unique @map("state_hash") @db.VarChar(128)
      expiresAt  DateTime  @map("expires_at") @db.Timestamptz(6)
      consumedAt DateTime? @map("consumed_at") @db.Timestamptz(6)
      createdAt  DateTime  @default(now()) @map("created_at") @db.Timestamptz(6)
      artist     Artist    @relation(fields: [artistId], references: [id], onDelete: Cascade)

      @@index([artistId, expiresAt])
      @@map("calendar_oauth_states")
    }

Add `calendarOauthStates CalendarOAuthState[]` to `Artist`.

- [ ] **Step 2: Generate and inspect the migration**

Run:

    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npx prisma migrate dev --name calendar_oauth_connection

Review that only the enum, nullable calendar name, OAuth state table, unique hash, index, and foreign key are added.

- [ ] **Step 3: Add persistence coverage**

The E2E test must create an artist, create a state row, assert the unique hash and cascade relation, mark it consumed, and clean up by deleting the artist. It must also assert that a connection stores `calendarName: 'InkSlot'` and `status: 'CONNECTED'`.

- [ ] **Step 4: Verify and commit**

Run:

    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npx prisma migrate status
    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build

Expected: migrations up to date and build passes. Commit:

    git add api/prisma/schema.prisma api/prisma/migrations api/test/calendar-persistence.e2e-spec.ts
    git commit -m "feat(api): persist calendar oauth state"

## Task 3: Implement encryption, provider boundary, and OAuth state service

**Files:**

- Create: `api/src/calendar/calendar.crypto.ts`
- Create: `api/src/calendar/calendar.crypto.spec.ts`
- Create: `api/src/calendar/calendar.provider.ts`
- Create: `api/src/calendar/google-calendar.provider.ts`
- Create: `api/src/calendar/calendar.state.service.ts`
- Create: `api/src/calendar/calendar.state.service.spec.ts`

**Interfaces:**

    export type CalendarSummary = {
      id: string;
      name: string;
    };

    export type CalendarTokens = {
      refreshToken: string;
    };

    export interface CalendarProvider {
      authorizationUrl(input: { state: string }): string;
      exchangeCode(code: string): Promise<CalendarTokens>;
      listCalendars(refreshToken: string): Promise<CalendarSummary[]>;
      revoke(refreshToken: string): Promise<void>;
    }

`CalendarStateService.create(artistId)` returns `{ state, expiresAt }`. `consume(state)` returns `{ artistId }` exactly once or throws `OAUTH_STATE_INVALID`.

- [ ] **Step 1: Write crypto tests**

Cover:

    it('round-trips a refresh token without returning plaintext payload');
    it('uses a different IV for two encryptions of the same token');
    it('rejects a tampered authentication tag');
    it('rejects keys that are not exactly 32 bytes');

- [ ] **Step 2: Implement AES-256-GCM**

Encode encrypted values as:

    v1:<iv>:<authTag>:<ciphertext>

Use a 12-byte random IV, `createCipheriv('aes-256-gcm', key, iv)`, and never include the key or plaintext in errors.

- [ ] **Step 3: Write state lifecycle tests**

Use a Prisma mock to verify that `create` stores only `sha256(state)` and that `consume` conditionally updates `consumedAt: null` and `expiresAt > now`. Cover missing, expired, and replayed states.

- [ ] **Step 4: Implement the state service**

Generate state with `randomBytes(32).toString('base64url')`. Store only its SHA-256 hash. Atomically set `consumedAt` on consumption and return the artist id.

- [ ] **Step 5: Implement the Google provider**

Use `google.auth.OAuth2(clientId, clientSecret, redirectUri)`. Authorization URL options:

    {
      access_type: 'offline',
      include_granted_scopes: true,
      prompt: 'consent',
      scope: configuredScopes,
      state,
    }

`exchangeCode` calls `getToken(code)` and rejects responses without a refresh token. `listCalendars` calls `calendar.calendarList.list({ minAccessRole: 'writer' })`. `revoke` revokes the refresh token. Map provider exceptions to internal codes without returning Google payloads.

- [ ] **Step 6: Test and commit**

Run:

    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/calendar/calendar.crypto.spec.ts src/calendar/calendar.state.service.spec.ts

Expected: PASS. Commit:

    git add api/src/calendar
    git commit -m "feat(api): add calendar oauth provider boundary"

## Task 4: Add Calendar connection use cases and admin routes

**Files:**

- Create: `api/src/calendar/calendar.service.ts`
- Create: `api/src/calendar/calendar.controller.ts`
- Create: `api/src/calendar/calendar.module.ts`
- Modify: `api/src/app.module.ts`
- Test: `api/test/calendar.e2e-spec.ts`

**Interfaces:**

- `GET /v1/admin/calendar/status` → `{ status, calendarId?, calendarName?, connectedAt?, updatedAt? }`.
- `GET /v1/admin/calendar/connect` → `{ authorizationUrl, expiresAt }`.
- `GET /v1/admin/calendar/callback?code=authorization-code&state=oauth-state` → `{ status: 'connected', calendarName: 'InkSlot' }`.
- `POST /v1/admin/calendar/disconnect` → `204` and deletes only the local connection.
- `POST /v1/admin/calendar/reconnect` → same response as `connect`.

- [ ] **Step 1: Write E2E tests first**

Cover with a fake `CalendarProvider`:

    it('returns 401 without an admin session');
    it('returns disconnected for an authenticated artist without a connection');
    it('creates a short-lived authorization URL and state');
    it('consumes the callback, selects the unique InkSlot calendar, and persists only the encrypted token');
    it('rejects a replayed or invalid state');
    it('rejects missing or ambiguous InkSlot calendars without creating a connection');
    it('disconnects locally without deleting appointments');
    it('maps revoked credentials to needs_reconnect');

The fake returns `{ id: 'inkslot-id', name: 'InkSlot' }` and `{ id: 'primary', name: 'Primary' }` when needed. Assert response bodies do not contain `refreshToken`, `authorizationCode`, or `clientSecret`.

- [ ] **Step 2: Implement status**

With no row return `disconnected`. With a row map Prisma enum values to lowercase API values and expose only calendar metadata and timestamps.

- [ ] **Step 3: Implement connect and reconnect**

Return `503 CALENDAR_NOT_CONFIGURED` if required env values are absent. Otherwise create a state, generate the provider URL, and return it. Reconnect must preserve existing appointments.

- [ ] **Step 4: Implement callback**

Handle `error=access_denied` as `OAUTH_ACCESS_DENIED`. Consume state before exchanging code. Exchange code, list calendars, require exactly one name equal to `GOOGLE_CALENDAR_NAME`, encrypt the refresh token, and upsert `CalendarConnection` as `CONNECTED`. On selection or provider error, do not persist the token.

- [ ] **Step 5: Implement disconnect**

Attempt provider revocation, then delete the local connection in a `finally` path. If Google revocation fails, remove the local token and return a safe response.

- [ ] **Step 6: Wire and test**

Register `CalendarModule` in `AppModule`, provide `GoogleCalendarProvider` under `CALENDAR_PROVIDER`, and export the service. Run:

    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false api/test/calendar.e2e-spec.ts

Expected: all Calendar cases pass. Commit:

    git add api/src/app.module.ts api/src/calendar api/test/calendar.e2e-spec.ts
    git commit -m "feat(api): add calendar connection routes"

## Task 5: Full verification and SDD evidence

**Files:**

- Modify: `context/local-development.md`
- Modify: `context/tasks/backlog.md`

- [ ] **Step 1: Document manual local flow**

Document that an authenticated admin calls `GET /v1/admin/calendar/connect`, opens the returned URL in the same browser, authorizes the test user, and checks `GET /v1/admin/calendar/status`. State that secrets remain in `api/.env` and the callback returns JSON in this slice.

- [ ] **Step 2: Run complete API verification**

Run:

    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run format
    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false
    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false
    PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run lint
    git diff --check

Expected: build and tests pass; lint has no errors; existing unsafe-argument warnings may remain.

- [ ] **Step 3: Verify secret hygiene**

Run:

    git status --short
    git grep -n -I -E 'GOCSPX-|client_secret|refreshToken|GOOGLE_CLIENT_SECRET=' -- ':!api/.env' ':!api/.env.example'

Expected: no real secret values and no generated credentials outside ignored local files. Do not print `api/.env`.

- [ ] **Step 4: Record progress and commit**

Update `context/tasks/backlog.md` with the tested endpoints and leave `freeBusy`, event sync, outbox, and Flutter Calendar UI pending. Commit:

    git add context/local-development.md context/tasks/backlog.md
    git commit -m "docs(context): record calendar oauth progress"

## Self-review checklist

- The plan implements only the approved OAuth connection slice.
- Every Google call is behind `CalendarProvider` and has a fake for tests.
- Refresh tokens are encrypted and never returned.
- Invalid, expired, and replayed states are covered.
- Calendar selection is unique by configured name `InkSlot`, never silently `primary`.
- The API can boot without Calendar configuration and reports a safe configuration error.
- The next plan can consume the provider boundary for `freeBusy` without changing OAuth persistence.


