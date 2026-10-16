# Public Availability and Time Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use the project SDD conventions in context/00-governance/AGENTS.md and implement one task at a time with a focused Conventional Commit.

**Goal:** Deliver real public availability for private booking links and a faithful Flutter Web date/time selection flow, stopping before review and confirmation.

**Architecture:** Keep token validation in the existing requests domain and add a public availability orchestration service in the availability module. The service loads the artist's persisted schedule, the request restrictions, internal busy intervals, and Google Calendar freeBusy, then delegates slot calculation to the existing pure AvailabilityEngine. Flutter receives only public DTOs through a repository and renders welcome, calendar, and curved time-wheel states through a Provider controller; selected slots remain in memory for T-013.

**Tech Stack:** NestJS 11, TypeScript, Prisma 6, PostgreSQL local, Luxon, the existing Google Calendar adapter, Jest/Supertest, Flutter Web 3.47.5 through FVM, Provider, GoRouter, package:http, and built-in Flutter calendar/wheel primitives.

## Global Constraints

- Keep workspace roots limited to app, api, and context.
- Use the already active local PostgreSQL service; do not add Docker, Compose, or a new database.
- Do not add a Prisma migration in T-012.
- Preserve Flutter Web + Provider + GoRouter, NestJS + TypeScript, PostgreSQL, and FVM Flutter 3.47.5.
- Use /v1/public/reservations/:token/availability as the only availability endpoint; do not add a legacy /slots route.
- Keep the server authoritative: Flutter never calculates or invents available slots.
- If Google Calendar cannot be verified, return 503 CALENDAR_UNAVAILABLE and render no slots.
- Keep raw public tokens only in the required deep-link path; never write them to storage, analytics, logs, route extras, or referrers intentionally.
- Never return public client contact, internal IDs, OAuth data, token hashes, or raw Calendar data.
- Preserve prototype tokens, assets, typography, Spanish copy, responsive behavior, reduced-motion behavior, and minimum 44 px interaction targets.
- Do not implement review/ticket, confirmation, idempotency, appointment creation, outbox, or Google event mutation; those belong to T-013 and later.
- Every task ends with focused verification and one small Conventional Commit.

## File Map

Create:

- api/src/availability/public-availability.dto.ts — validated date-range query.
- api/src/availability/public-availability.service.ts — public context orchestration and engine input.
- api/src/availability/public-availability.controller.ts — public availability endpoint.
- api/test/public-availability.e2e-spec.ts — local PostgreSQL/API behavior and isolation coverage.
- app/lib/features/public_booking/domain/public_reservation.dart — public summary/restriction models.
- app/lib/features/public_booking/domain/public_availability.dart — day and slot models.
- app/lib/features/public_booking/data/public_reservation_repository.dart — public HTTP mappings.
- app/lib/features/public_booking/presentation/public_reservation_controller.dart — Provider state and selection.
- app/lib/features/public_booking/presentation/public_dates_page.dart — real date and slot screen.
- app/lib/features/public_booking/presentation/widgets/public_calendar.dart — month/day grid.
- app/lib/features/public_booking/presentation/widgets/public_time_wheel.dart — curved time selector.
- app/lib/features/public_booking/presentation/widgets/public_state_panel.dart — safe public loading/error/empty states.
- app/test/features/public_booking/public_reservation_test.dart — DTO/domain parsing.
- app/test/features/public_booking/public_reservation_repository_test.dart — HTTP mapping.
- app/test/features/public_booking/public_reservation_controller_test.dart — Provider state transitions.
- app/test/features/public_booking/public_dates_page_test.dart — calendar and selection widgets.
- app/test/features/public_booking/public_time_wheel_test.dart — wheel interaction/reduced motion.

Modify:

- api/src/requests/requests.service.ts — internal public availability context.
- api/src/requests/requests.module.ts — export request service for availability orchestration.
- api/src/availability/availability.module.ts — import request/calendar modules and register public service/controller/engine.
- api/test/requests.e2e-spec.ts — preserve/extend public response assumptions if the shared context refactor changes fixtures.
- app/lib/app.dart — share one owned HTTP client and public controller.
- app/lib/core/router/app_router.dart — inject public controller and connect public routes.
- app/lib/features/public_booking/presentation/public_welcome_page.dart — replace visual fixtures with real summary state.
- app/lib/features/public_booking/presentation/public_dates_placeholder.dart — leave as an unused compatibility file after route references are migrated; remove it only if repository-wide reference search confirms no test or library import remains.
- context/tasks/backlog.md — record T-012 evidence and keep T-013 pending.

---

## Task 1: Expose a safe public availability context

**Files:**

- Modify: api/src/requests/requests.service.ts
- Modify: api/src/requests/requests.module.ts
- Modify: api/src/requests/public-reservations.service.spec.ts
- Modify: api/src/requests/requests.service.spec.ts

**Interfaces:**

```ts
export type PublicAvailabilityContext = {
  requestId: string;
  artistId: string;
  status: 'pending';
  durationMinutes: number;
  timezone: string;
  expiresAt: Date;
  minDate: string | null;
  maxDate: string | null;
  allowedWeekdays: number[] | null;
  allowedWindows: Array<{ startLocal: string; endLocal: string }> | null;
};

class BookingRequestsService {
  resolvePublicAvailabilityContext(
    token: string,
  ): Promise<PublicAvailabilityContext>;
}
```

- [ ] Step 1: Add a shared token lookup path. Refactor the current public token lookup only enough to share hash lookup and lifecycle validation between resolvePublic and the new context method. Preserve existing TOKEN_NOT_FOUND, TOKEN_EXPIRED, and TOKEN_REVOKED envelopes and the special booked summary behavior of resolvePublic.
- [ ] Step 2: Define the context projection. For an active pending request, return only artist ID, request ID, duration, study timezone, expiry, and normalized date/weekday/time-window restrictions. Do not include client, contact, payment, token hash, Calendar connection, or raw token fields.
- [ ] Step 3: Handle booked requests explicitly. If the token maps to a BOOKED request, throw ConflictException with code ALREADY_BOOKED and the safe Spanish message already used by the request lifecycle.
- [ ] Step 4: Add regression tests. Verify context projection, active token expiry, revoked token, expired token, booked request, public response privacy, and artist data isolation. Export BookingRequestsService from RequestsModule; do not import AvailabilityModule into RequestsModule.
- [ ] Step 5: Verify and commit.

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/requests/requests.service.spec.ts src/requests/public-reservations.service.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/requests/requests.service.ts src/requests/requests.module.ts src/requests/requests.service.spec.ts src/requests/public-reservations.service.spec.ts
git commit -m "feat(api): expose public availability context"
```

## Task 2: Implement the public availability endpoint

**Files:**

- Create: api/src/availability/public-availability.dto.ts
- Create: api/src/availability/public-availability.service.ts
- Create: api/src/availability/public-availability.controller.ts
- Modify: api/src/availability/availability.module.ts
- Create: api/test/public-availability.e2e-spec.ts
- Modify only if needed: api/src/availability/availability.engine.spec.ts

**Interfaces:**

```ts
export class PublicAvailabilityQueryDto {
  from!: string;
  to!: string;
}

export type PublicAvailabilityResponse = {
  timezone: string;
  days: Array<{
    date: string;
    slots: Array<{ startAt: string; endAt: string }>;
  }>;
};

export class PublicAvailabilityService {
  get(
    token: string,
    query: PublicAvailabilityQueryDto,
  ): Promise<PublicAvailabilityResponse>;
}
```

- [ ] Step 1: Add strict query validation. Validate date-only values with the exact YYYY-MM-DD shape, reject impossible dates, reject from after to, and reject ranges longer than 31 inclusive days with 400 BAD_REQUEST. Do not accept client timezone or timestamps.
- [ ] Step 2: Wire the public controller. Add Controller('public/reservations') with Get(':token/availability'), inject the service, and rely on the existing global ValidationPipe for whitelist/forbid-non-whitelisted query behavior. Do not add an admin guard to this route.
- [ ] Step 3: Load persisted scheduling inputs. Use the public context artistId and timezone, then load StudioSettings, weekly windows, intersecting AvailabilityBlock rows, and intersecting Appointment rows with statuses CONFIRMED, COMPLETED, or NO_SHOW. Convert SQL time values to HH:mm using UTC clock extraction.
- [ ] Step 4: Query Calendar and run the engine. Build the local range from the start of from through the start of the day after to, convert the range to UTC, call CalendarService.queryBusy with timeMin, timeMax, and timeZone, and pass normalized external intervals plus persisted inputs to AvailabilityEngine.calculate with now: new Date() and calendarVerifiable: true. Let CALENDAR_UNAVAILABLE propagate unchanged. Map missing settings or invalid persisted scheduling configuration to safe 503 AVAILABILITY_NOT_CONFIGURED.
- [ ] Step 5: Register modules without cycles. Make AvailabilityModule import AuthModule, RequestsModule, and CalendarModule; provide AvailabilityEngine, PublicAvailabilityService, and the public controller. RequestsModule must remain independent of AvailabilityModule.
- [ ] Step 6: Write E2E coverage. Against the active local PostgreSQL database, create isolated artists, settings, weekly windows, requests, blocks, appointments, and tokens. Override CalendarService in the Nest test module with a deterministic fake returning busy intervals or throwing ServiceUnavailableException. Cover active slots, no slots, restrictions, internal block/citation exclusion, UTC output, invalid ranges, token statuses, booked state, artist isolation, and Calendar failure. Assert public responses contain only timezone, days, date, startAt, and endAt.
- [ ] Step 7: Verify and commit.

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/availability/availability.engine.spec.ts src/requests/requests.service.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add src/availability test/public-availability.e2e-spec.ts
git commit -m "feat(api): add public availability endpoint"
```

## Task 3: Add public Flutter data flow and shared dependency composition

**Files:**

- Create: app/lib/features/public_booking/domain/public_reservation.dart
- Create: app/lib/features/public_booking/domain/public_availability.dart
- Create: app/lib/features/public_booking/data/public_reservation_repository.dart
- Create: app/lib/features/public_booking/presentation/public_reservation_controller.dart
- Modify: app/lib/app.dart
- Modify: app/lib/core/router/app_router.dart
- Create: app/test/features/public_booking/public_reservation_test.dart
- Create: app/test/features/public_booking/public_reservation_repository_test.dart
- Create: app/test/features/public_booking/public_reservation_controller_test.dart

**Interfaces:**

```dart
enum PublicReservationStatus { idle, loading, active, booked, expired, revoked, error }
enum PublicAvailabilityStatus { idle, loading, ready, empty, calendarUnavailable, offline, error }

class PublicReservationRepository {
  Future<PublicReservation> getReservation(String token);
  Future<PublicAvailability> getAvailability(
    String token, {
    required DateTime from,
    required DateTime to,
  });
}

class PublicReservationController extends ChangeNotifier {
  Future<void> loadReservation(String token);
  Future<void> loadAvailability(String token, DateTime from, DateTime to);
  void selectDate(DateTime? date);
  void selectSlot(AvailabilitySlot? slot);
  Future<void> retryReservation();
  Future<void> retryAvailability();
}
```

- [ ] Step 1: Define strict public models. Parse the existing public summary and availability response. Keep date-only values separate from UTC slot instants; reject malformed dates, statuses, timezone strings, or slot intervals with FormatException/ApiException rather than dropping invalid entries.
- [ ] Step 2: Implement repository mappings. Use the injected ApiClient, encode from/to as local YYYY-MM-DD without converting date-only values through UTC, map HTTP 404/410/409/503/network errors to controller-visible typed states, and never include the token in logs or request error messages.
- [ ] Step 3: Implement controller state. Store one current token in memory, separate summary/availability statuses, preserve the latest requested range for retry, clear stale selected day/slot when a new response invalidates it, and map API error codes to terminal, booked, calendarUnavailable, offline, or generic error states.
- [ ] Step 4: Compose one HTTP client. In InkSlotApp, own one HttpApiClient, AuthRepository, AdminSessionController, BookingRequestsController, and PublicReservationController; call restore once; pass controllers to AppRouter; dispose router/controllers/client exactly once. Preserve injectable controller arguments for existing router tests.
- [ ] Step 5: Add focused tests. Cover model parsing, date-only query encoding, UTC slot parsing, empty response, all API error mappings, selection reset, retry range, and controller notification state transitions. Use a fake ApiClient; do not contact local API from Dart unit tests.
- [ ] Step 6: Verify and commit. Before implementation of affected Flutter APIs, resolve/query Context7 for current GoRouter and Flutter Web patterns used by the repository.

```bash
cd app
fvm dart format lib test
fvm flutter test test/features/public_booking/public_reservation_test.dart test/features/public_booking/public_reservation_repository_test.dart test/features/public_booking/public_reservation_controller_test.dart
fvm flutter analyze
git diff --check
git add lib/app.dart lib/core/router lib/features/public_booking/domain lib/features/public_booking/data lib/features/public_booking/presentation/public_reservation_controller.dart test/features/public_booking
git commit -m "feat(app): add public availability data flow"
```

## Task 4: Replace public welcome fixtures and render the availability calendar

**Files:**

- Modify: app/lib/core/router/app_router.dart
- Modify: app/lib/features/public_booking/presentation/public_welcome_page.dart
- Create: app/lib/features/public_booking/presentation/public_dates_page.dart
- Create: app/lib/features/public_booking/presentation/widgets/public_calendar.dart
- Create: app/lib/features/public_booking/presentation/widgets/public_state_panel.dart
- Keep unused for compatibility after route migration; remove only if `rg` confirms no repository reference remains.
- Create: app/test/features/public_booking/public_dates_page_test.dart

- [ ] Step 1: Connect /r/:token to real summary state. Provide the shared public controller to the route, load the token once per deep link, and render real artist display name, duration, expiry, timezone, and restrictions without fixture values. The CTA navigates to /r/:token/dates only for active pending requests.
- [ ] Step 2: Build public safe-state panels. Implement reusable loading, expired/revoked, booked, Calendar unavailable, offline, generic error, and no-slots panels with Spanish copy, retry/back behavior, semantics, reduced-motion transitions, and no fake values.
- [ ] Step 3: Build the date range. On dates page entry, derive a visible local date range from today and the reservation min/max restrictions, cap the request at 31 days, call loadAvailability, and provide previous/next range controls only when they remain within request/horizon bounds. Do not enable a date that is absent or has zero slots.
- [ ] Step 4: Implement the calendar grid. Create a custom tokenized month/day grid without adding a calendar dependency. Render weekday labels, month title, selected-day pop, disabled days, available-day copper marker, focus ring, keyboard traversal, 44 px targets, and responsive width for 390 px and desktop.
- [ ] Step 5: Test real states. Use an injected controller with deterministic data to cover active welcome, expired, booked, no slots, Calendar unavailable, selected/disabled days, deep-link navigation, and preservation of public/admin router behavior.
- [ ] Step 6: Verify and commit.

```bash
cd app
fvm dart format lib test
fvm flutter test test/features/public_booking/public_dates_page_test.dart test/features/public_booking/public_reservation_controller_test.dart
fvm flutter analyze
git diff --check
git add lib/core/router lib/features/public_booking/presentation test/features/public_booking/public_dates_page_test.dart
git commit -m "feat(app): render public availability calendar"
```

## Task 5: Add the curved time wheel and slot selection

**Files:**

- Create: app/lib/features/public_booking/presentation/widgets/public_time_wheel.dart
- Modify: app/lib/features/public_booking/presentation/public_dates_page.dart
- Create: app/test/features/public_booking/public_time_wheel_test.dart

- [ ] Step 1: Render selected-day slots. Show slots formatted in the study timezone supplied by the API while retaining UTC instants in the model for T-013. Do not use browser locale as the source of truth for the slot date.
- [ ] Step 2: Implement the wheel. Use ListWheelScrollView/FixedExtentScrollController or a focused custom scroll implementation with AnimationController, Transform, perspective, scale, opacity, and copper glow. Keep neighboring slots readable, expose arrow controls, support tap/drag/mouse wheel/keyboard, and wrap options in semantic labels.
- [ ] Step 3: Implement reduced motion. When MediaQuery.disableAnimationsOf(context) is true, replace animated transforms with a stable selected list or static wheel styling while preserving selection and focus. Do not start repeating or offscreen animations.
- [ ] Step 4: Store selection only. Call controller.selectSlot on selection and show the prototype's non-confirming selected-state affordance without navigating to review or calling a confirmation endpoint. The selected slot must not enter GoRouter.extra, local storage, analytics, or logs.
- [ ] Step 5: Test interaction and visuals. Cover empty slot list, initial selection, tap, arrow/keyboard selection, scroll selection, reduced motion, semantics, slot timezone labels, and no route/token leakage.
- [ ] Step 6: Verify and commit.

```bash
cd app
fvm dart format lib test
fvm flutter test test/features/public_booking/public_time_wheel_test.dart test/features/public_booking/public_dates_page_test.dart
fvm flutter analyze
git diff --check
git add lib/features/public_booking/presentation test/features/public_booking/public_time_wheel_test.dart
git commit -m "feat(app): add public time wheel selection"
```

## Task 6: Run the full gate and record T-012 evidence

**Files:**

- Modify: context/tasks/backlog.md
- Modify source files only if a focused verification correction is required.

- [ ] Step 1: Verify database and migrations. Confirm pg_isready -h 127.0.0.1 -p 5432, run Prisma migration status, and do not print values from api/.env.
- [ ] Step 2: Run the API gate.

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run test:e2e -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
```

Expected: all unit suites, all E2E suites, and Nest build pass; availability E2E uses the fake Calendar provider and local PostgreSQL.

- [ ] Step 3: Run the Flutter gate.

```bash
cd ../app
fvm dart format lib test
fvm flutter test
fvm flutter analyze
fvm flutter build web --dart-define=API_BASE_URL=http://localhost:3000/v1
```

Expected: no analyzer issues, all widget/unit tests pass, and Web build succeeds. Existing SVG metadata or icon tree-shaking warnings are acceptable only if the process exits successfully and no visual asset is missing.

- [ ] Step 4: Update SDD evidence. Change the backlog row/evidence to state that T-012 now covers public availability endpoint, real welcome data, date grid, time wheel, safe states, and tests. Leave T-013 explicitly pending for ticket/confirm/idempotency.
- [ ] Step 5: Inspect and commit documentation. Run git diff --check, git status --short, verify only app, api, and context changed, verify prototype/PDF/reference files and secrets are not staged, then commit the backlog evidence.

```bash
git add context/tasks/backlog.md
git commit -m "docs(context): record public availability slice"
```

## Definition of Done

- GET /v1/public/reservations/:token/availability returns only server-calculated UTC slots and safe errors.
- Active private links display real reservation data and availability without mock values.
- Date selection and curved time wheel work responsively and accessibly with reduced-motion support.
- Token expiry, revocation, booked state, empty availability, offline, and Calendar failure have explicit UI states.
- API unit/E2E, Flutter tests/analyze, and Web build pass with local PostgreSQL active.
- T-012 is documented as complete and T-013 remains the next slice.
