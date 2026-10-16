# Calendar Outbox Worker Implementation Plan

> **For agentic workers:** implement one task at a time using the project SDD conventions and a focused Conventional Commit. Steps use checkbox syntax for tracking.

**Goal:** Deliver T-014 as a local NestJS vertical slice that processes appointment.calendar.create outbox events into idempotent Google Calendar events, retries recoverable failures, and exposes scoped synchronization incidents.

**Architecture:** Add an in-process NestJS worker backed by @nestjs/schedule. PostgreSQL claims outbox rows with FOR UPDATE SKIP LOCKED and a lease stored in the existing nextAttemptAt field. CalendarSyncService uses CalendarService as the safe boundary around OAuth decryption and CalendarProvider; deterministic event IDs make provider retries at-least-once but externally idempotent. A small admin sync-issues module lists and requeues failures by authenticated artist.

**Tech Stack:** NestJS 11, TypeScript 5.7, @nestjs/schedule, Prisma 6.19, PostgreSQL local, googleapis 186, Jest 30, Supertest, and the existing Calendar OAuth/freeBusy adapter.

## Global Constraints

- Keep top-level workspace directories limited to app, api, and context.
- Use local PostgreSQL; do not add Docker, Compose, Redis, an external queue, or a second required service.
- Do not add a Prisma migration in T-014; reuse OutboxEvent.nextAttemptAt as the processing lease.
- Process only appointment.calendar.create; reprogramming, cancellation, deletion, and event update belong to T-016.
- Keep the existing Calendar OAuth, freeBusy, token encryption, and safe error contracts unchanged.
- Never return or log OAuth codes, refresh tokens, token hashes, client contact data, internal secrets, or raw Google errors.
- Use a deterministic SHA-256 hexadecimal Google event ID derived from inkslot:appointment:<appointmentId>.
- Use sendUpdates: none, UTC instants, and the persisted IANA studio timezone for Google event creation.
- Treat the outbox as at-least-once delivery. A retry must not create a second Google event or a second CalendarEvent row.
- Automatic retries use five maximum attempts, 30-second exponential-backoff base, 15-minute cap, and ±20% jitter unless overridden by the named environment variables.
- OUTBOX_WORKER_ENABLED defaults to enabled outside NODE_ENV=test; tests must call drainOnce() directly and never contact Google.
- API endpoints require AdminSessionGuard and scope all incident reads/writes through the authenticated artist.
- Preserve Spanish safe messages and the existing HTTP error envelope; do not add Flutter UI in this slice.
- Consult Context7 before changing NestJS Schedule, Prisma transaction/raw SQL, or googleapis APIs. Sources checked: /nestjs/schedule, /nestjs/docs.nestjs.com, /prisma/web, /googleapis/google-api-nodejs-client.
- Every task ends with focused verification and one small Conventional Commit.

## File Map

Create:

- api/src/sync/sync.constants.ts — injection token and operation names.
- api/src/sync/sync.config.ts — strict worker environment parsing.
- api/src/sync/sync.module.ts — Schedule, Calendar, Prisma, and auth composition.
- api/src/sync/outbox-worker.service.ts — interval, claim, lease, and drain orchestration.
- api/src/sync/calendar-sync.service.ts — create-event handler and deterministic ID.
- api/src/sync/sync-issues.service.ts — failure recording, listing, and manual retry.
- api/src/sync/sync-issues.controller.ts — authenticated admin endpoints.
- api/src/sync/sync-issues.dto.ts — strict list query DTO.
- api/src/sync/calendar-sync.service.spec.ts — handler state transitions.
- api/src/sync/outbox-worker.service.spec.ts — claim/retry/lease orchestration.
- api/src/sync/sync-issues.service.spec.ts — scoped issue operations.
- api/test/calendar-outbox.e2e-spec.ts — PostgreSQL/provider-fake integration.

Modify:

- api/package.json and api/package-lock.json — add @nestjs/schedule.
- api/src/main.ts — enable Nest shutdown hooks.
- api/src/app.module.ts — import SyncModule.
- api/src/calendar/calendar.provider.ts — add create/get event contracts.
- api/src/calendar/google-calendar.provider.ts — implement Calendar v3 event calls.
- api/src/calendar/calendar.service.ts — safe create/get event boundary and reauth handling.
- api/src/calendar/calendar.module.ts — export the service/provider needed by sync.
- api/test/calendar.e2e-spec.ts and existing Calendar fakes — implement the expanded provider interface.
- context/tasks/backlog.md — record T-014 evidence after the full gate.

---

## Task 1: Extend the Calendar adapter for idempotent event creation

**Files:**

- Modify: api/package.json, api/package-lock.json
- Modify: api/src/calendar/calendar.provider.ts
- Modify: api/src/calendar/google-calendar.provider.ts
- Modify: api/src/calendar/calendar.service.ts
- Modify: api/src/calendar/calendar.module.ts
- Modify: api/src/main.ts
- Modify: api/src/calendar/calendar.service.spec.ts, api/src/calendar/google-calendar.provider.spec.ts, api/test/calendar.e2e-spec.ts

**Interfaces:**

~~~ts
export type CalendarEventInput = {
  refreshToken: string;
  calendarId: string;
  eventId: string;
  summary: string;
  description: string;
  startAt: Date;
  endAt: Date;
  timeZone: string;
};

export type CalendarEventResult = {
  externalEventId: string;
  etag: string | null;
};

export interface CalendarProvider {
  createEvent(input: CalendarEventInput): Promise<CalendarEventResult>;
  getEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<CalendarEventResult | null>;
}
~~~

CalendarProviderError also gains CALENDAR_EVENT_EXISTS so a deterministic insert conflict is recoverable through getEvent rather than treated as a generic failure.

- [ ] Step 1: Run npm install @nestjs/schedule from api and add app.enableShutdownHooks() after NestFactory.create() and before listen(). Preserve the global prefix, CORS, and validation options.
- [ ] Step 2: Write failing provider tests for events.insert, events.get, null on 404, and safe mapping of 401/403/5xx errors.
- [ ] Step 3: Add the exact types above and update every fake provider found with rg -n "CalendarProvider|as jest.Mocked<CalendarProvider>" src test.
- [ ] Step 4: Implement GoogleCalendarProvider with calendar.events.insert using calendarId, sendUpdates none, requestBody id, summary, description, start/end RFC3339 date-times, and timezone. Implement events.get for recovery. Map 404 to null, 401/403 to CALENDAR_REAUTH_REQUIRED, and other failures to CALENDAR_UNAVAILABLE without provider text.
- [ ] Step 5: Add CalendarService.createEvent(artistId, inputWithoutRefreshToken) and getEvent(artistId, eventId). Require a connected connection, decrypt only in memory, delegate to the provider, return typed CalendarProviderError values to the sync module, and call markNeedsReconnect for CALENDAR_REAUTH_REQUIRED. Preserve queryBusy HTTP mapping and behavior.
- [ ] Step 6: Run focused tests, Nest build, git diff --check, then commit:

~~~bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/calendar/calendar.service.spec.ts src/calendar/google-calendar.provider.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add package.json package-lock.json src/main.ts src/calendar test/calendar.e2e-spec.ts
git commit -m "feat(api): add calendar event adapter"
~~~

Expected: focused tests and build pass; no secret appears in test output.

---

## Task 2: Add worker configuration, module composition, and atomic claims

**Files:**

- Create: api/src/sync/sync.constants.ts, api/src/sync/sync.config.ts, api/src/sync/sync.module.ts, api/src/sync/outbox-worker.service.ts, api/src/sync/outbox-worker.service.spec.ts
- Modify: api/src/app.module.ts

**Interfaces:**

~~~ts
export type SyncConfig = {
  enabled: boolean;
  pollIntervalMs: number;
  batchSize: number;
  leaseMs: number;
  maxAttempts: number;
  retryBaseMs: number;
  retryMaxMs: number;
  jitterRatio: number;
};

export type ClaimedOutboxEvent = {
  id: string;
  aggregateId: string;
  type: string;
  payload: unknown;
  attempts: number;
};

export type SyncFailureCode =
  | 'CALENDAR_REAUTH_REQUIRED'
  | 'CALENDAR_UNAVAILABLE'
  | 'APPOINTMENT_NOT_FOUND'
  | 'OUTBOX_PAYLOAD_INVALID'
  | 'SYNC_ATTEMPTS_EXHAUSTED';

export type SyncFailure = {
  code: SyncFailureCode;
  message: string;
  retryable: boolean;
};

class OutboxWorkerService {
  drainOnce(): Promise<number>;
}
~~~

- [ ] Step 1: Write configuration tests for defaults, NODE_ENV=test disabling, explicit OUTBOX_WORKER_ENABLED=false, integer bounds, retryMaxMs >= retryBaseMs, and jitterRatio in [0, 1].
- [ ] Step 2: Write failing claim tests verifying batch size, pending due rows, stale processing rows, incremented attempts, lease timestamp, and no overlapping local drain.
- [ ] Step 3: Implement strict configuration and module composition. Register ScheduleModule.forRoot(), PrismaModule, CalendarModule, and AuthModule in SyncModule; import SyncModule from AppModule; provide SyncConfig through an injection token. Keep the worker disabled under tests.
- [ ] Step 4: Implement the atomic claim with one Prisma $queryRaw transaction: pending due or stale processing rows, ORDER BY COALESCE(next_attempt_at, created_at), FOR UPDATE SKIP LOCKED, LIMIT 1, update to PROCESSING, increment attempts, set next_attempt_at to now plus lease, and return a typed event or null.
- [ ] Step 5: Register a named Schedule interval only when enabled, call drainOnce without overlap, process up to the configured batch, stop future polling during shutdown, and prevent one event from aborting the batch.
- [ ] Step 6: Run focused tests, build, diff check, stage src/sync and app.module.ts, and commit:

~~~bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/sync/outbox-worker.service.spec.ts src/sync/sync.config.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/sync src/app.module.ts
git commit -m "feat(api): add local outbox worker"
~~~

---

## Task 3: Implement the successful and idempotent create handler

**Files:**

- Create: api/src/sync/calendar-sync.service.ts, api/src/sync/calendar-sync.service.spec.ts
- Modify: api/src/sync/sync.constants.ts

**Interfaces:**

~~~ts
class CalendarSyncService {
  process(event: ClaimedOutboxEvent): Promise<CalendarSyncSuccess>;
  deterministicEventId(appointmentId: string): string;
}

type CalendarSyncSuccess = {
  appointmentId: string;
  calendarId: string;
  externalEventId: string;
  etag: string | null;
};

class CalendarSyncError extends Error {
  constructor(readonly failure: SyncFailure);
}
~~~

- [ ] Step 1: Write failing handler tests for strict payload parsing, deterministic lowercase hexadecimal event ID, connected artist lookup, event title/description, CalendarService delegation, existing CalendarEvent short-circuit, and provider-conflict recovery through getEvent.
- [ ] Step 2: Implement payload and event projection. Parse only appointmentId UUID plus operation create; load Appointment with client, settings, and artist Calendar connection; reject missing/incompatible records by throwing CalendarSyncError with a terminal SyncFailure. Use SHA-256 of inkslot:appointment:<appointmentId>. Use InkSlot — <client name> and Reserva InkSlot · <duration> min without email, phone, payment data, or internal IDs.
- [ ] Step 3: Implement provider recovery. If CalendarEvent exists, finalize locally. Otherwise call CalendarService.createEvent; on external conflict call CalendarService.getEvent with the deterministic ID and finalize only when found. Never issue a second insert with a new ID.
- [ ] Step 4: Return CalendarSyncSuccess after the external event is created or recovered. Do not write CalendarEvent, Appointment, OutboxEvent, or SyncIssue from this handler; Task 4 finalizes all database state in one short Prisma transaction. Treat an existing CalendarEvent as a successful outcome.
- [ ] Step 5: Keep worker dispatch integration out of this task. The handler exposes typed safe failures for Task 4 to connect without changing the claim contract.
- [ ] Step 6: Run focused tests, build, diff check, stage src/sync, and commit:

~~~bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/sync/calendar-sync.service.spec.ts src/sync/outbox-worker.service.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/sync
git commit -m "feat(api): sync appointments to calendar"
~~~

---

## Task 4: Add retry, dead-letter, and synchronization issue persistence

**Files:**

- Create: api/src/sync/sync-issues.service.ts, api/src/sync/sync-issues.service.spec.ts
- Modify: api/src/sync/outbox-worker.service.ts, api/src/sync/calendar-sync.service.ts, api/src/sync/sync.module.ts

**Interfaces:**

~~~ts
class SyncIssuesService {
  finalizeSuccess(
    outboxId: string,
    success: CalendarSyncSuccess,
  ): Promise<void>;
  finalizeFailure(
    event: ClaimedOutboxEvent,
    failure: SyncFailure,
    config: SyncConfig,
  ): Promise<void>;
}
~~~

- [ ] Step 1: Write failure-matrix tests for temporary unavailable, max attempts, reauth, malformed payload, and missing appointment.
- [ ] Step 2: Calculate min(retryMaxMs, retryBaseMs * 2 ** (attempts - 1)) and multiply by a random factor in [1-jitterRatio, 1+jitterRatio]. Inject randomness in tests.
- [ ] Step 3: In one Prisma transaction, finalize CalendarSyncSuccess by creating CalendarEvent with appointment unique key, external ID, calendar ID, etag, and lastSyncedAt; update appointment SYNCED; update the claimed outbox COMPLETED with nextAttemptAt null; and resolve the matching open SyncIssue. For failures, update outbox status/next attempt, appointment sync status, Calendar connection state when required, and one open SyncIssue with only the approved safe code/message. Treat a unique CalendarEvent race as read-and-finalize.
- [ ] Step 4: Map CalendarProviderError and CalendarSyncError, missing connection, invalid payload, missing appointment, and unknown errors to the exact SyncFailure values; call CalendarSyncService.process for each claim, then finalize success or failure without aborting the batch. Never store raw Error.message.
- [ ] Step 5: Run focused tests, build, diff check, stage src/sync, and commit:

~~~bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/sync/sync-issues.service.spec.ts src/sync/calendar-sync.service.spec.ts src/sync/outbox-worker.service.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/sync
git commit -m "feat(api): add outbox retry lifecycle"
~~~

---

## Task 5: Expose scoped admin synchronization issues and manual retry

**Files:**

- Create: api/src/sync/sync-issues.controller.ts, api/src/sync/sync-issues.dto.ts
- Modify: api/src/sync/sync-issues.service.ts, api/src/sync/sync.module.ts

**Interfaces:**

~~~ts
export class ListSyncIssuesDto {
  status?: 'open' | 'resolved';
}

class SyncIssuesService {
  list(artistId: string, query: ListSyncIssuesDto): Promise<{
    items: Array<{
      id: string;
      appointmentId: string;
      operation: string;
      code: string;
      message: string;
      status: 'open' | 'resolved';
      lastAttemptAt: string | null;
      createdAt: string;
    }>;
  }>;
  retry(artistId: string, issueId: string): Promise<{ status: 'queued' }>;
}
~~~

- [ ] Step 1: Write controller/service tests for 401, scoped list ordering and limit 50, safe fields, foreign issue 404, owner-only retry, and idempotent retry when already queued.
- [ ] Step 2: Use IsOptional and IsIn(['open', 'resolved']) with the existing global validation pipe. Default to open.
- [ ] Step 3: Join SyncIssue to Appointment and filter appointment.artistId = artistId; order by lastAttemptAt DESC NULLS LAST, createdAt DESC, take 50, and map enum values to lowercase. Retry must locate the linked appointment.calendar.create outbox inside the same scope and reset outbox PENDING, attempts 0, nextAttemptAt now, and appointment PENDING in one transaction.
- [ ] Step 4: Add guarded routes GET /admin/sync-issues and POST /admin/sync-issues/:id/retry with AdminSessionGuard and AuthenticatedRequest. Register the controller from SyncModule.
- [ ] Step 5: Run focused tests, build, diff check, stage src/sync, and commit:

~~~bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/sync/sync-issues.service.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/sync
git commit -m "feat(api): expose sync issue recovery"
~~~

---

## Task 6: Verify PostgreSQL integration, retry recovery, and no-duplicate guarantees

**Files:**

- Create: api/test/calendar-outbox.e2e-spec.ts
- Modify: api/test/calendar.e2e-spec.ts for the provider fake methods already required by Task 1.

- [ ] Step 1: Build isolated fixtures with unique artist, connected Calendar, studio settings, client, confirmed appointment, and pending outbox against local PostgreSQL. Override CALENDAR_PROVIDER with a deterministic fake; never load or print api/.env values in assertions.
- [ ] Step 2: Call app.get(OutboxWorkerService).drainOnce() and assert one provider create, one CalendarEvent, appointment SYNCED, outbox COMPLETED, nextAttemptAt null, no open issue, and no contact data, refresh token, or internal ID in event content.
- [ ] Step 3: Make the fake throw CALENDAR_UNAVAILABLE, assert PENDING plus future retry time, then succeed and drain again. Simulate a create that succeeds externally but throws locally; on retry getEvent returns the same event and insert count remains one.
- [ ] Step 4: Cover reauth (NEEDS_RECONNECT, appointment FAILED, outbox FAILED, safe issue), five-attempt exhaustion, invalid payload, missing appointment, and safe issue messages without provider details or refresh tokens.
- [ ] Step 5: Start two drainOnce calls against two worker instances for the same due outbox and assert one external event, one CalendarEvent, one completed outbox, and a synced appointment. Use a fake provider barrier to exercise the claim race.
- [ ] Step 6: Authenticate two local artists; assert owner list visibility, foreign issue 404, retry resets only the owner event, and a subsequent drain succeeds.
- [ ] Step 7: Run focused E2E, Nest build, git diff --check, stage the E2E files, and commit:

~~~bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false test/calendar-outbox.e2e-spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add test/calendar-outbox.e2e-spec.ts test/calendar.e2e-spec.ts
git commit -m "test(api): verify calendar outbox recovery"
~~~

---

## Task 7: Run the full gate and record T-014 evidence

**Files:**

- Modify: context/tasks/backlog.md

- [ ] Step 1: Run pg_isready -h 127.0.0.1 -p 5432 with local access and npx prisma migrate status from api; expect accepting connections and no pending migrations. Never print api/.env.
- [ ] Step 2: Run the API unit, E2E, and build gate:

~~~bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
~~~

Expected: all existing and T-014 suites pass, no migration is generated, and no provider fake leaks secrets.
- [ ] Step 3: Run git diff --check and git status --short; scan tracked diffs for refreshToken, clientSecret, authorization-code, and .env values without printing file contents; verify only api and context changed; confirm prototype/PDF/reference assets are not staged.
- [ ] Step 4: Add a dated T-014 entry to context/tasks/backlog.md describing the in-process worker, atomic claim/lease, deterministic Calendar event, retry/dead-letter, scoped issue endpoints, no-duplicate E2E, and exact gate counts. Keep T-016 pending for update/delete and reprogramming.
- [ ] Step 5: Stage and commit the evidence:

~~~bash
git add context/tasks/backlog.md
git commit -m "docs(context): record calendar outbox slice"
~~~

## Definition of Done

- A confirmed T-013 appointment produces exactly one idempotent Google event projection.
- PostgreSQL claims pending/stale outbox rows safely across concurrent workers.
- A provider timeout retries with bounded exponential backoff and jitter.
- An authorization failure marks the connection NEEDS_RECONNECT and creates a safe incident.
- Exhausted or permanent failures become FAILED with a recoverable SyncIssue.
- Manual retry is scoped to the owning artist and reuses the deterministic event identity.
- API unit tests, PostgreSQL E2E tests, Nest build, diff checks, and secret/scope checks pass.
- T-014 is documented complete; T-016 remains next for appointment actions and Calendar update/delete.
