# Public Booking Confirmation Implementation Plan

> For agentic workers: implement one task at a time using the project SDD conventions and a focused Conventional Commit.

**Goal:** Deliver T-013 as a vertical slice: safe public confirmation, PostgreSQL transaction, idempotency replay, durable Calendar outbox, review ticket, result screen, and post-confirmation lookup.

**Architecture:** Reuse the current public availability engine for exact-slot preflight. Add an appointments module for confirmation and public appointment lookup. The service checks Calendar freeBusy before the write transaction, locks the booking request, creates the appointment/outbox/idempotency record atomically, and exposes safe DTOs. Flutter extends the existing Provider controller and HTTP client with in-memory idempotency and review/result routes.

**Tech Stack:** NestJS 11, TypeScript 5.7, Prisma 6.19, PostgreSQL local, Luxon, Jest 30, Supertest, Flutter Web 3.47.5 through FVM, Provider, GoRouter 17, package:http, and existing InkSlot tokens/assets.

## Global Constraints

- Keep top-level workspace directories limited to app, api, and context.
- Use local PostgreSQL; do not add Docker, Compose, services, or migrations in T-013.
- Reuse Appointment, IdempotencyKey, OutboxEvent, BookingToken, the unique request constraint, and appointments_no_overlap.
- Expose only POST /v1/public/reservations/:token/confirm and GET /v1/public/reservations/:token/appointment.
- Require UTC startAt, a printable Idempotency-Key of 1–128 characters, and reject unknown body fields.
- Hash the key, token scope, and normalized payload with SHA-256; never log or persist clear values.
- Call Calendar freeBusy before any write; failure returns 503 CALENDAR_UNAVAILABLE and leaves PostgreSQL unchanged.
- Persist Appointment CONFIRMED/PENDING, an appointment.calendar.create outbox event, and the replay body in one serializable transaction.
- Retain idempotency responses for 24 hours; same key and normalized payload replay the stored status/body.
- Do not implement event creation, worker/retry/backoff, reprogramming, cancellation, complete/no-show, admin appointment UI, or messaging.
- Public responses contain no PII, internal IDs, OAuth data, raw Calendar data, token hashes, or idempotency keys.
- Preserve Spanish copy, ticket/result composition, reduced motion, semantics, keyboard access, and 44 px targets.
- Consult Context7 before changing NestJS, Prisma, Flutter, or GoRouter APIs. Sources checked for this plan: /nestjs/docs.nestjs.com, /prisma/web, /flutter/website.
- Every task ends with focused verification and one Conventional Commit.

## File Map

Create:

- api/src/availability/public-slot-check.types.ts
- api/src/availability/public-availability.service.spec.ts
- api/src/appointments/appointments.module.ts
- api/src/appointments/public-confirmation.dto.ts
- api/src/appointments/public-confirmation.types.ts
- api/src/appointments/public-confirmation.service.ts
- api/src/appointments/public-confirmation.controller.ts
- api/src/appointments/public-confirmation.service.spec.ts
- api/test/public-confirmation.e2e-spec.ts
- app/lib/features/public_booking/domain/public_confirmation.dart
- app/lib/features/public_booking/domain/public_appointment.dart
- app/lib/features/public_booking/presentation/public_review_page.dart
- app/lib/features/public_booking/presentation/public_result_page.dart
- app/test/features/public_booking/public_confirmation_test.dart
- app/test/features/public_booking/public_confirmation_controller_test.dart
- app/test/features/public_booking/public_review_page_test.dart
- app/test/features/public_booking/public_result_page_test.dart

Modify:

- api/src/availability/public-availability.service.ts
- api/src/availability/availability.module.ts
- api/src/requests/requests.service.ts
- api/src/requests/requests.service.spec.ts
- api/src/app.module.ts
- app/lib/core/network/api_client.dart
- app/lib/features/public_booking/data/public_reservation_repository.dart
- app/lib/features/public_booking/presentation/public_reservation_controller.dart
- app/lib/features/public_booking/presentation/public_dates_page.dart
- app/lib/core/router/app_router.dart
- app/lib/features/public_booking/presentation/widgets/public_state_panel.dart
- app/test/core/network/api_client_test.dart and every ApiClient fake
- context/tasks/backlog.md

---

## Task 1: Extract reusable exact-slot availability preflight

**Files:** create api/src/availability/public-slot-check.types.ts and api/src/availability/public-availability.service.spec.ts; modify api/src/availability/public-availability.service.ts and api/src/availability/availability.module.ts.

**Interface produced:**

```ts
import type { AvailabilityResult } from './availability.engine';

export type PublicSlotCheck = {
  startAt: Date;
  endAt: Date;
  timezone: string;
  refreshed: AvailabilityResult;
};

class PublicAvailabilityService {
  assertSlotAvailable(
    token: string,
    startAt: Date,
  ): Promise<PublicSlotCheck>;
}
```

- [ ] Step 1: Write failing tests for an exact returned slot, a missing slot producing 409 SLOT_UNAVAILABLE with public availability, an internal block/appointment conflict, and Calendar failure producing 503 CALENDAR_UNAVAILABLE. Reuse the Prisma/Calendar fake patterns from api/test/public-availability.e2e-spec.ts.
- [ ] Step 2: Run the focused test and verify the new method is missing.

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/availability/public-availability.service.spec.ts
```

Expected: the new suite fails before implementation.
- [ ] Step 3: Extract one private loader in PublicAvailabilityService for settings, weekly windows, blocks, appointments, external busy intervals, and AvailabilityEngine input. Make both get and assertSlotAvailable use that loader.
- [ ] Step 4: Convert startAt to the study-local day with Luxon, calculate that one-day range, compute endAt from the request duration, and accept only a returned slot with exact UTC start/end equality. For mismatch throw ConflictException with error code SLOT_UNAVAILABLE and a refreshed public availability result. Preserve existing safe Calendar/configuration exceptions.
- [ ] Step 5: Export AvailabilityEngine and PublicAvailabilityService from AvailabilityModule so AppointmentsModule can reuse the service without importing a controller.
- [ ] Step 6: Verify and commit.

```bash
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/availability/public-availability.service.spec.ts src/availability/availability.engine.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/availability/public-slot-check.types.ts src/availability/public-availability.service.ts src/availability/public-availability.service.spec.ts src/availability/availability.module.ts
git commit -m "refactor(api): share exact public slot preflight"
```

---

## Task 2: Implement the confirmation module and transaction

**Files:** create api/src/appointments/appointments.module.ts, public-confirmation.dto.ts, public-confirmation.types.ts, public-confirmation.service.ts, public-confirmation.controller.ts, and public-confirmation.service.spec.ts; modify api/src/requests/requests.service.ts, api/src/requests/requests.service.spec.ts, and api/src/app.module.ts.

**Interfaces:**

```ts
export class PublicConfirmDto {
  @IsString()
  @Matches(/^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$/)
  startAt!: string;
}

export type PublicConfirmationResponse = {
  status: 'confirmed';
  syncStatus: 'pending' | 'synced' | 'failed';
  startAt: string;
  endAt: string;
  timezone: string;
};

export type PublicAppointmentResponse = PublicConfirmationResponse;
```

```ts
class PublicConfirmationService {
  confirm(
    token: string,
    idempotencyKey: string | undefined,
    input: PublicConfirmDto,
  ): Promise<PublicConfirmationResponse>;
  getAppointment(token: string): Promise<PublicAppointmentResponse>;
}
```

- [ ] Step 1: Add BookingRequestsService.resolvePublicAppointmentContext(token), returning only requestId, artistId, and timezone for BOOKED requests, including consumed tokens. Reject pending/expired/revoked/not-found safely and add unit tests for privacy.
- [ ] Step 2: Add DTO/controller tests for route paths, missing/invalid Idempotency-Key, strict UTC body, and unknown fields. Read the header with @Headers('idempotency-key'); never log it.
- [ ] Step 3: Implement SHA-256 hashes with Node createHash. Use scope equal to a fixed prefix plus the SHA-256 token hash. Normalize startAt to ISO UTC and hash exactly {startAt: normalizedIso}. Before active-token validation, replay an existing IdempotencyKey with the same requestHash; throw 409 IDEMPOTENCY_REUSED for a different hash.
- [ ] Step 4: Call PublicAvailabilityService.assertSlotAvailable before opening the write transaction. Use Prisma interactive transaction options isolationLevel Serializable, maxWait 5000, and timeout 10000. Lock the request with this exact SQL shape:

```ts
await tx.$queryRaw(
  Prisma.sql`SELECT id FROM "booking_requests" WHERE id = ${requestId} FOR UPDATE`,
);
```

Revalidate PENDING request/token, insert Appointment CONFIRMED/PENDING, update request to BOOKED with version increment, consume the token, create the outbox payload { appointmentId, operation: 'create' }, and persist IdempotencyKey with the exact 201-safe response.
- [ ] Step 5: Wrap the complete transaction in two attempts. Retry only sqlState 40001 or 40P01, checking the error and error.cause. Map exclusion SQLSTATE 23P01 and appointment uniqueness conflicts to safe 409 errors.
- [ ] Step 6: Implement getAppointment through the safe booked context, load the appointment, lowercase status/syncStatus, and return only date/time/timezone fields. Return 404 APPOINTMENT_NOT_FOUND when absent.
- [ ] Step 7: Register AppointmentsModule with RequestsModule and AvailabilityModule, add the public controller/service, and import it from AppModule.
- [ ] Step 8: Run unit tests/build and commit.

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/appointments/public-confirmation.service.spec.ts src/requests/requests.service.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/appointments src/requests/requests.service.ts src/requests/requests.service.spec.ts src/app.module.ts
git commit -m "feat(api): add idempotent public confirmation"
```

---

## Task 3: Verify PostgreSQL confirmation, lookup, and concurrency E2E

**Files:** create api/test/public-confirmation.e2e-spec.ts; modify api/test/requests.e2e-spec.ts only for reusable fixture helpers.

- [ ] Step 1: Create isolated fixtures for artist, connected Calendar row, studio settings, weekly window, client, pending request, and active token. Use unique IDs and delete only suite-owned records. Do not print api/.env.
- [ ] Step 2: POST a valid slot and assert 201, safe fields only, request BOOKED, token consumed, one Appointment CONFIRMED/PENDING, and one OutboxEvent with type appointment.calendar.create and status PENDING.
- [ ] Step 3: Repeat the same key/payload and assert exact replay. Reuse the key with another startAt and assert 409 IDEMPOTENCY_REUSED. Query appointment with the consumed token and assert safe response. Scan bodies for absence of token, key, hash, client, and IDs.
- [ ] Step 4: Cover malformed UTC, missing/invalid key, expired/revoked/not-found token, already booked, internal conflict, Calendar busy conflict, and Calendar unavailable. For pre-commit failures assert no appointment, status transition, token consumption, idempotency row, or outbox row.
- [ ] Step 5: Send two concurrent POST requests with different keys for the same request/slot and assert one 201 and one 409, one appointment, one consumed token, one BOOKED request, and one outbox event:

```ts
const responses = await Promise.all([
  request(app.getHttpServer()).post(path).set('Idempotency-Key', 'race-a').send(body),
  request(app.getHttpServer()).post(path).set('Idempotency-Key', 'race-b').send(body),
]);
expect(responses.map((r) => r.status).sort()).toEqual([201, 409]);
```

- [ ] Step 6: Verify and commit.

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false test/public-confirmation.e2e-spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add test/public-confirmation.e2e-spec.ts test/requests.e2e-spec.ts
git commit -m "test(api): verify public confirmation concurrency"
```

---

## Task 4: Add Flutter models, headers, repository, and controller state

**Files:** create app/lib/features/public_booking/domain/public_confirmation.dart, public_appointment.dart, and the two focused test files; modify app/lib/core/network/api_client.dart, the public repository/controller, repository tests, and every ApiClient fake found by rg.

**Interfaces:**

```dart
class PublicConfirmation {
  const PublicConfirmation({
    required this.status,
    required this.syncStatus,
    required this.startAt,
    required this.endAt,
    required this.timezone,
  });

  final String status;
  final String syncStatus;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;
}

class PublicAppointment {
  const PublicAppointment({
    required this.status,
    required this.syncStatus,
    required this.startAt,
    required this.endAt,
    required this.timezone,
  });

  final String status;
  final String syncStatus;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;
}
```

```dart
Future<Map<String, dynamic>> postJson(
  String path, {
  Map<String, dynamic>? body,
  Map<String, String>? headers,
});
```

```dart
Future<PublicConfirmation> confirmReservation(
  String token,
  DateTime startAt, {
  required String idempotencyKey,
});
Future<PublicAppointment> getAppointment(String token);
```

- [ ] Step 1: Write tests for UTC model parsing, supported statuses, endpoint paths, exact Idempotency-Key header, POST startAt payload, appointment lookup, and ApiException propagation.
- [ ] Step 2: Add optional headers to ApiClient.postJson and HttpApiClient; merge them into the request after accept/content-type. Update all fakes without changing existing callers. Use the current ApiClient test to assert the header reaches the HTTP request.
- [ ] Step 3: Implement models that reject malformed/non-UTC instants, unsupported status/syncStatus, invalid timezone, and missing fields with FormatException.
- [ ] Step 4: Implement repository methods for POST /public/reservations/:token/confirm and GET /public/reservations/:token/appointment. Encode the token as one path segment, send ISO UTC startAt and Idempotency-Key, and keep token/key out of exception messages.
- [ ] Step 5: Add PublicConfirmationStatus with idle, loading, confirmed, conflict, alreadyBooked, expired, revoked, calendarUnavailable, offline, and error. Add confirmSelected and loadAppointment. Reuse one in-memory key after network/unknown-result failure when the selected slot is unchanged; clear it after slot change or success. Notify once per state transition.
- [ ] Step 6: Run focused tests/analyze and commit.

```bash
cd app
fvm dart format lib test
fvm flutter test test/features/public_booking/public_confirmation_test.dart test/features/public_booking/public_confirmation_controller_test.dart test/features/public_booking/public_reservation_repository_test.dart
fvm flutter analyze
git diff --check
git add lib/core/network/api_client.dart lib/features/public_booking app/test/core/network app/test/features/public_booking
git commit -m "feat(app): add public confirmation data flow"
```

---

## Task 5: Render review ticket, confirmation states, and result routes

**Files:** create app/lib/features/public_booking/presentation/public_review_page.dart, public_result_page.dart, and their widget tests; modify app/lib/core/router/app_router.dart, public_dates_page.dart, public_reservation_controller.dart only for route actions, and public_state_panel.dart for approved confirmation states.

- [ ] Step 1: Write widget tests for disabled review CTA without a selection, selected-slot navigation, ticket summary in study timezone, confirm loader, confirmed pending result, conflict CTA, token/calendar/offline panels, result reload through getAppointment, deep-linked review without selection, and reduced motion.
- [ ] Step 2: Add onReview to PublicDatesPage. Show the prototype selected-state CTA only with a slot and navigate to /r/:token/review. Keep slot only in the shared controller, never route extras.
- [ ] Step 3: Render the review ticket with existing InkSlot colors/fonts/time helpers and tkIn/tilt. Use MediaQuery.disableAnimationsOf(context) for a stable accessible ticket. Confirm calls controller.confirmSelected and navigates to result only after a confirmed response.
- [ ] Step 4: Render the result from in-memory confirmation; when absent call loadAppointment. Show pending/synced/failed messaging, stamp/ring success, retry, return-to-dates, and “Ver mi reserva” without internal data.
- [ ] Step 5: Register /r/:token/review and /r/:token/result with the shared PublicReservationController. A deep-linked review/result without state shows a safe fallback and never fabricates a booking. Preserve admin redirects.
- [ ] Step 6: Run focused tests/analyze and commit.

```bash
cd app
fvm dart format lib test
fvm flutter test test/features/public_booking/public_review_page_test.dart test/features/public_booking/public_result_page_test.dart test/features/public_booking/public_dates_page_test.dart
fvm flutter analyze
git diff --check
git add lib/core/router/app_router.dart lib/features/public_booking/presentation app/test/features/public_booking
git commit -m "feat(app): add public confirmation review and result"
```

---

## Task 6: Run the full gate and record T-013 evidence

**Files:** modify context/tasks/backlog.md.

- [ ] Step 1: Verify PostgreSQL with pg_isready -h 127.0.0.1 -p 5432 and Prisma migration status. Never print api/.env.
- [ ] Step 2: Run the API gate.

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
```

Expected: all unit suites, all E2E suites, and Nest build pass; no migration is generated.
- [ ] Step 3: Run the Flutter gate.

```bash
cd ../app
fvm dart format lib test
fvm flutter test
fvm flutter analyze
fvm flutter build web --dart-define=API_BASE_URL=http://localhost:3000/v1
```

Expected: tests pass, analyzer reports no issues, and Web build succeeds. Known SVG metadata, icon tree-shaking, and Wasm dry-run warnings are acceptable only with exit code 0.
- [ ] Step 4: Inspect scope/security with git diff --check, git status --short, a token/key/PII log scan, verification that only app/api/context changed, and confirmation that prototype/PDF/secrets are not staged.
- [ ] Step 5: Update context/tasks/backlog.md with T-013 endpoint, transaction, replay, outbox, concurrency, review/result, and gate evidence. Keep T-014 explicitly pending for event worker/retry.
- [ ] Step 6: Commit the evidence.

```bash
git add context/tasks/backlog.md
git commit -m "docs(context): record public booking confirmation slice"
```

## Definition of Done

- A valid public slot confirms through the API with a required idempotency key.
- Exactly one appointment is created, the request becomes BOOKED, the token is consumed, one outbox event is written, and replay data is stored.
- Same-key retries replay; different payloads conflict; concurrent confirmation has one winner.
- FreeBusy failure leaves PostgreSQL unchanged and returns a safe 503.
- Public appointment lookup exposes only safe date/time/sync fields.
- Flutter review, loading, result, conflict, pending-sync, offline, and token states match the approved prototype with reduced motion.
- API unit/E2E/build and Flutter test/analyze/Web build pass with local PostgreSQL.
- T-013 is documented complete and T-014 remains next.

