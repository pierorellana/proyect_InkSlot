# Admin Requests UI and Contact Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use the project SDD conventions in `context/00-governance/AGENTS.md` and implement one task at a time with a focused Conventional Commit.

**Goal:** Deliver the T-011 administrative flow from the approved design: authenticated Flutter Web session, responsive admin shell, request creation, secure link handoff, request list/detail, and lifecycle actions backed by the existing NestJS API.

**Architecture:** Extend the existing request aggregate with optional contact-channel metadata and an optional payment reference, preserving the existing email/phone contract for compatibility. Add a Flutter HTTP boundary with an ephemeral in-memory session, Provider controllers for request state, and GoRouter guards for admin routes. Screens consume repositories/controllers only; raw booking tokens are never persisted, logged, or placed in URLs.

**Tech Stack:** Flutter Web 3.47.5 through FVM, Provider, GoRouter, `package:http`, NestJS 11, TypeScript, Prisma 6, PostgreSQL local, class-validator, Jest, Supertest, and the approved InkSlot design tokens/assets already present in the workspace.

## Global Constraints

- Keep the workspace roots limited to `app`, `api`, and `context`.
- Use local PostgreSQL and Prisma migrations; do not add Docker or cloud infrastructure.
- Preserve Flutter Web + Provider, NestJS + TypeScript, PostgreSQL, and FVM Flutter 3.47.5.
- Preserve the existing prototype visual language: typography, palette, spacing, radii, icons, motion, responsive breakpoints, and Spanish product copy. Reuse existing tokens and assets instead of introducing parallel systems.
- Keep API base configuration injectable with `--dart-define=API_BASE_URL`; default local development to `http://localhost:3000/v1`.
- Keep admin data artist-scoped on the server. The client must not send or choose an `artistId`.
- Keep raw booking tokens in ephemeral memory only. Do not put them in route parameters, query strings, local storage, provider persistence, logs, analytics, or audit records.
- Treat `401` as an expired session and redirect to `/admin/login`; show safe API error messages for all other failures.
- Do not implement dashboard metrics, appointments, public availability, confirmation/outbox, automatic messaging, or new prototype functionality in this slice.
- The prototype and PDF under `context/references` remain reference-only and are not copied into product assets or pushed.
- Run focused tests after each task and make one small Conventional Commit per task.

## Approved API/UI Contract

The API extension is intentionally additive:

```ts
type ContactChannel = 'whatsapp' | 'instagram' | 'email' | 'phone';

type CreateBookingRequestInput = {
  clientName: string;
  contactChannel?: ContactChannel;
  contactValue?: string;
  paymentReference?: string;
  depositVerified: boolean;
  durationMinutes: number;
  restrictionNotes?: string;
  preferredDate?: string;
  preferredTimeRange?: string;
  preferredDays?: string[];
  tokenTtlHours?: number;
};
```

`contactChannel` and `contactValue` are supplied together or omitted together. Email validates as an email; WhatsApp/phone accept a non-empty value up to 32 characters; Instagram accepts a non-empty value up to 64 characters. `paymentReference` is optional and capped at 160 characters. Existing `email` and `phone` fields remain available for backwards compatibility and are populated only when their semantics match the selected channel.

The admin response exposes `contactChannel`, `contactValue`, and `paymentReference`; public reservation responses do not expose any of them. The API status `closed` is rendered in the prototype's cancelled/terminal filter with a distinct `Cerrada` chip, so no extra filter is invented in the UI.

## File Map

Create:

- `api/prisma/migrations/20261016110000_booking_contact_metadata/migration.sql`
- `app/lib/core/config/app_config.dart`
- `app/lib/core/network/api_client.dart`
- `app/lib/core/network/api_exception.dart`
- `app/lib/features/auth/data/auth_repository.dart`
- `app/lib/features/auth/domain/admin_user.dart`
- `app/lib/features/auth/presentation/admin_session_controller.dart`
- `app/lib/features/auth/presentation/admin_login_page.dart`
- `app/lib/features/admin/presentation/admin_shell.dart`
- `app/lib/features/admin/presentation/admin_requests_placeholder.dart`
- `app/lib/features/requests/domain/booking_request_status.dart`
- `app/lib/features/requests/domain/booking_request.dart`
- `app/lib/features/requests/data/booking_requests_repository.dart`
- `app/lib/features/requests/presentation/booking_requests_controller.dart`
- `app/lib/features/requests/presentation/new_booking_request_page.dart`
- `app/lib/features/requests/presentation/link_ready_page.dart`
- `app/lib/features/requests/presentation/booking_requests_page.dart`
- `app/lib/features/requests/presentation/booking_request_detail_page.dart`
- `app/lib/features/requests/presentation/widgets/contact_channel_field.dart`
- `app/lib/features/requests/presentation/widgets/request_form_sections.dart`
- `app/lib/features/requests/presentation/widgets/booking_request_card.dart`
- `app/lib/features/requests/presentation/widgets/booking_request_status_chip.dart`
- `app/lib/features/requests/presentation/widgets/request_action_sheet.dart`
- `app/test/core/network/api_client_test.dart`
- `app/test/features/auth/admin_session_controller_test.dart`
- `app/test/features/auth/admin_login_page_test.dart`
- `app/test/features/admin/admin_router_test.dart`
- `app/test/features/requests/booking_request_test.dart`
- `app/test/features/requests/booking_requests_controller_test.dart`
- `app/test/features/requests/new_booking_request_page_test.dart`
- `app/test/features/requests/link_ready_page_test.dart`
- `app/test/features/requests/booking_requests_page_test.dart`
- `app/test/features/requests/booking_request_detail_page_test.dart`

Modify:

- `api/prisma/schema.prisma`
- `api/src/requests/requests.dto.ts`
- `api/src/requests/requests.service.ts`
- `api/src/requests/requests.service.spec.ts`
- `api/src/requests/public-reservations.service.spec.ts`
- `api/test/requests.e2e-spec.ts`
- `app/pubspec.yaml`
- `app/pubspec.lock`
- `app/lib/app.dart`
- `app/lib/core/router/app_router.dart`
- `app/test/smoke_test.dart`
- `context/tasks/backlog.md`

---

## Task 1: Persist request contact metadata and payment reference

**Files:**

- Modify: `api/prisma/schema.prisma`
- Create: `api/prisma/migrations/20261016110000_booking_contact_metadata/migration.sql`
- Modify: `api/src/requests/requests.dto.ts`
- Modify: `api/src/requests/requests.service.ts`
- Modify: `api/src/requests/requests.service.spec.ts`
- Modify: `api/src/requests/public-reservations.service.spec.ts`
- Modify: `api/test/requests.e2e-spec.ts`

**Interfaces:**

```ts
type ContactChannel = 'whatsapp' | 'instagram' | 'email' | 'phone';

type AdminBookingRequestResponse = {
  client: {
    name: string;
    email: string | null;
    phone: string | null;
    contactChannel: ContactChannel | null;
    contactValue: string | null;
  };
  paymentReference: string | null;
};
```

- [ ] **Step 1: Extend Prisma additively.** Add nullable `contactChannel VARCHAR(32)` and `contactValue VARCHAR(320)` to `Client`, plus nullable `paymentReference VARCHAR(160)` to `BookingRequest`, using the project's existing snake_case mappings and indexes. Do not rename or remove `email`, `phone`, or any token column.

- [ ] **Step 2: Write and inspect the migration.** Use this SQL so existing rows remain valid:

```sql
ALTER TABLE "clients"
  ADD COLUMN "contact_channel" VARCHAR(32),
  ADD COLUMN "contact_value" VARCHAR(320);

ALTER TABLE "booking_requests"
  ADD COLUMN "payment_reference" VARCHAR(160);
```

Run from `api` with the repository's Node 24 binary:

```bash
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH /Users/jorge/.nvm/versions/node/v24.5.0/bin/node ./node_modules/prisma/build/index.js validate
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH /Users/jorge/.nvm/versions/node/v24.5.0/bin/node ./node_modules/prisma/build/index.js migrate deploy
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH /Users/jorge/.nvm/versions/node/v24.5.0/bin/node ./node_modules/prisma/build/index.js generate
```

If the local database is unavailable, report it as an environment prerequisite; do not weaken the migration or add a mock database path.

- [ ] **Step 3: Extend DTO validation.** Add optional channel/value/reference fields to the create DTO. Validate the channel enum, require channel and value as a pair, apply channel-specific length/email rules, trim values before persistence, and reject a blank payment reference while allowing it to be omitted.

- [ ] **Step 4: Map legacy fields safely.** In the create transaction, map `email` to `email` only for the email channel, `phone` to `phone` for phone/WhatsApp, and clear both legacy fields for Instagram. For existing clients, preserve stored contact data unless the request explicitly supplies the new contact pair. Persist `paymentReference` on the booking request. Include the new fields only in admin list/detail/renew responses; keep public resolution responses unchanged.

- [ ] **Step 5: Add regression coverage.** Cover Instagram and payment reference persistence, email and WhatsApp mappings, missing channel/value pairs, invalid email, overlong values, and the absence of contact/reference fields in public responses. Verify artist scoping remains unchanged.

- [ ] **Step 6: Verify and commit.**

```bash
cd api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false src/requests/booking-token.spec.ts src/requests/requests.service.spec.ts src/requests/public-reservations.service.spec.ts
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add prisma/schema.prisma prisma/migrations/20261016110000_booking_contact_metadata src/requests/requests.dto.ts src/requests/requests.service.ts src/requests/requests.service.spec.ts src/requests/public-reservations.service.spec.ts test/requests.e2e-spec.ts
git commit -m "feat(api): persist request contact metadata"
```

## Task 2: Add Flutter HTTP and session foundations

**Files:**

- Modify: `app/pubspec.yaml`
- Modify: `app/pubspec.lock`
- Create: `app/lib/core/config/app_config.dart`
- Create: `app/lib/core/network/api_client.dart`
- Create: `app/lib/core/network/api_exception.dart`
- Create: `app/lib/features/auth/data/auth_repository.dart`
- Create: `app/lib/features/auth/domain/admin_user.dart`
- Create: `app/lib/features/auth/presentation/admin_session_controller.dart`
- Create: `app/test/core/network/api_client_test.dart`
- Create: `app/test/features/auth/admin_session_controller_test.dart`

**Interfaces:**

```dart
class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  bool get isUnauthorized => statusCode == 401;
}

abstract class ApiClient {
  Future<Map<String, dynamic>> getJson(String path);
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  });
}

enum AdminSessionStatus { checking, signedOut, signedIn, failure }

class AdminSessionController extends ChangeNotifier {
  AdminSessionStatus get status;
  AdminUser? get user;
  String? get errorMessage;
  Future<void> restore();
  Future<void> login(String email, String password);
  Future<void> logout();
  void clearError();
}
```

- [ ] **Step 1: Confirm current dependency APIs with Context7.** Resolve and query the current `package:http` documentation for Flutter Web `BrowserClient` and the selected Web Share package before writing code. Add only the verified package APIs with `fvm flutter pub add`; do not guess a package name or version. The HTTP client must send credentials for the existing cookie-based API session.

- [ ] **Step 2: Implement configuration and safe API errors.** Read `API_BASE_URL` with `String.fromEnvironment`, normalize trailing slashes, inject an `http.Client` for tests, use `BrowserClient` with credentials in Web, decode the existing JSON error envelope, and expose only safe status/code/message values.

- [ ] **Step 3: Implement auth repository/controller.** Add login, current-user, and logout calls against the existing NestJS auth routes. Keep session state in memory; on app start call `restore`, on login call `me`, and on `401` transition to `signedOut` without retry loops.

- [ ] **Step 4: Test the boundary.** Use a fake HTTP client to verify base URL/path joining, credentials configuration, JSON decoding, non-2xx mapping, login success, login failure, restore, and logout. Run:

```bash
cd app
fvm dart format lib test
fvm flutter test test/core/network/api_client_test.dart test/features/auth/admin_session_controller_test.dart
```

- [ ] **Step 5: Commit.**

```bash
git diff --check
git add pubspec.yaml pubspec.lock lib/core/config lib/core/network lib/features/auth test/core/network test/features/auth
git commit -m "feat(app): add admin api and session foundation"
```

## Task 3: Implement protected admin routing and shell

**Files:**

- Modify: `app/lib/app.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/test/smoke_test.dart`
- Create: `app/lib/features/auth/presentation/admin_login_page.dart`
- Create: `app/lib/features/admin/presentation/admin_shell.dart`
- Create: `app/lib/features/admin/presentation/admin_requests_placeholder.dart`
- Create: `app/test/features/auth/admin_login_page_test.dart`
- Create: `app/test/features/admin/admin_router_test.dart`

**Routes:**

```text
/admin/login
/admin
/admin/requests
/admin/requests/new
/admin/requests/link
/admin/requests/:id
```

- [ ] **Step 1: Compose app-level dependencies.** Create one `ApiClient`, `AuthRepository`, and `AdminSessionController` in `InkSlotApp`; dispose owned resources correctly and preserve all existing public routes.

- [ ] **Step 2: Add redirects.** Make GoRouter listen to session changes. Redirect signed-out users from admin routes to `/admin/login`, signed-in users away from login to `/admin/requests`, and leave `/`, `/r/:token`, and public date routes unchanged. Preserve no sensitive redirect query state.

- [ ] **Step 3: Build the login screen.** Reproduce the approved prototype hierarchy, logo treatment, typography, validation, loading, safe error state, keyboard semantics, and reduced-motion behavior using existing theme tokens. Submit through the controller and navigate only after success.

- [ ] **Step 4: Build the responsive shell.** Add the desktop side rail and mobile bottom navigation from the prototype, with active route state, logout action, max-width/content constraints, and a placeholder requests destination until Task 6. Avoid inventing dashboard cards.

- [ ] **Step 5: Test and commit.** Verify redirects for checking/signed-out/signed-in states, login validation, failed login, shell navigation, and the existing public smoke route.

```bash
cd app
fvm dart format lib test
fvm flutter test test/smoke_test.dart test/features/auth/admin_login_page_test.dart test/features/admin/admin_router_test.dart
fvm flutter analyze
git diff --check
git add lib/app.dart lib/core/router lib/features/auth/presentation/admin_login_page.dart lib/features/admin test/smoke_test.dart test/features/auth/admin_login_page_test.dart test/features/admin/admin_router_test.dart
git commit -m "feat(app): add protected admin shell"
```

## Task 4: Add request models, repository, and Provider controller

**Files:**

- Create: `app/lib/features/requests/domain/booking_request_status.dart`
- Create: `app/lib/features/requests/domain/booking_request.dart`
- Create: `app/lib/features/requests/data/booking_requests_repository.dart`
- Create: `app/lib/features/requests/presentation/booking_requests_controller.dart`
- Modify: `app/lib/app.dart`
- Create: `app/test/features/requests/booking_request_test.dart`
- Create: `app/test/features/requests/booking_requests_controller_test.dart`

**Interfaces:**

```dart
enum BookingRequestStatus { pending, booked, cancelled, expired, closed }
enum ContactChannel { whatsapp, instagram, email, phone }

class BookingRequestPage {
  final List<BookingRequest> items;
  final String? nextCursor;
}

class CreateBookingRequestInput {
  final String clientName;
  final ContactChannel? contactChannel;
  final String? contactValue;
  final String? paymentReference;
  final bool depositVerified;
  final int durationMinutes;
  final String? restrictionNotes;
  final DateTime? preferredDate;
  final String? preferredTimeRange;
  final List<String> preferredDays;
  final int? tokenTtlHours;
}

class LinkReadyData {
  final String path;
  final DateTime expiresAt;
}

class BookingRequestsController extends ChangeNotifier {
  Future<void> load({bool refresh = false});
  Future<void> loadMore();
  Future<void> loadDetail(String id);
  Future<LinkReadyData?> create(CreateBookingRequestInput input);
  Future<LinkReadyData?> renew(String id, {int? ttlHours});
  Future<void> revoke(String id);
  Future<void> close(String id);
  void clearError();
}
```

- [ ] **Step 1: Model strict, nullable API data.** Parse current and extended response fields without assuming optional legacy fields exist. Map unknown status values to a controlled parse error rather than silently showing the wrong lifecycle state. Keep dates in UTC internally and format only at the view layer.

- [ ] **Step 2: Implement repository mappings.** Map create/filter/cursor/detail/lifecycle calls to the existing `/requests` endpoints. Send only defined optional values, encode dates as ISO-8601, and return raw link tokens only in a `LinkReadyData` result held by the controller.

- [ ] **Step 3: Implement Provider controller state.** Separate list, detail, and mutation loading/error states; append cursor pages without duplicates; invalidate/reload after revoke or close; expose a `401` boundary for the router. Register the controller once in the app composition and dispose it.

- [ ] **Step 4: Test serialization and state transitions.** Cover status/channel parsing, null fields, cursor pagination, create payloads, successful create/renew, failed mutation, and session expiration. Run `fvm dart format`, the two focused test files, and `fvm flutter analyze`.

- [ ] **Step 5: Commit.**

```bash
git diff --check
git add lib/app.dart lib/features/requests test/features/requests
git commit -m "feat(app): add booking requests provider flow"
```

## Task 5: Implement new request and link-ready screens

**Files:**

- Create: `app/lib/features/requests/presentation/new_booking_request_page.dart`
- Create: `app/lib/features/requests/presentation/link_ready_page.dart`
- Create: `app/lib/features/requests/presentation/widgets/contact_channel_field.dart`
- Create: `app/lib/features/requests/presentation/widgets/request_form_sections.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Create: `app/test/features/requests/new_booking_request_page_test.dart`
- Create: `app/test/features/requests/link_ready_page_test.dart`

- [ ] **Step 1: Build the form from the prototype sections.** Include client name, channel/value, deposit confirmation, duration, restrictions, preferred date/time range/days, and token TTL. Validate pair semantics and channel-specific contact input before calling the controller. Keep fields keyboard accessible and preserve the desktop/mobile layouts.

- [ ] **Step 2: Wire create behavior.** Show field and request errors in the existing visual language, disable duplicate submit while loading, retain entered values after recoverable errors, and navigate to `/admin/requests/link` only after a successful response.

- [ ] **Step 3: Build secure link handoff.** Show the URL/path with the prototype's visual hierarchy and expiry information. Copy through the platform clipboard API. Use the verified Web Share package from Task 2 where available and a clear fallback when unavailable. Do not render or persist a raw token beyond this ephemeral page state; leaving the page clears it.

- [ ] **Step 4: Test the user flow.** Cover validation, channel changes, disabled submit, successful navigation, API error retention, link expiry display, copy feedback, null-safe share fallback, and the absence of token values from route state. Run focused widget tests and `fvm flutter analyze`.

- [ ] **Step 5: Commit.**

```bash
git diff --check
git add lib/core/router lib/features/requests/presentation test/features/requests/new_booking_request_page_test.dart test/features/requests/link_ready_page_test.dart
git commit -m "feat(app): add request creation and link screens"
```

## Task 6: Implement request list, detail, and lifecycle actions

**Files:**

- Create: `app/lib/features/requests/presentation/booking_requests_page.dart`
- Create: `app/lib/features/requests/presentation/booking_request_detail_page.dart`
- Create: `app/lib/features/requests/presentation/widgets/booking_request_card.dart`
- Create: `app/lib/features/requests/presentation/widgets/booking_request_status_chip.dart`
- Create: `app/lib/features/requests/presentation/widgets/request_action_sheet.dart`
- Modify: `app/lib/features/admin/presentation/admin_shell.dart`
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/test/features/admin/admin_router_test.dart`
- Create: `app/test/features/requests/booking_requests_page_test.dart`
- Create: `app/test/features/requests/booking_request_detail_page_test.dart`
- Modify: `context/tasks/backlog.md`

- [ ] **Step 1: Build the list.** Render the prototype request cards, status chips, search/filter controls, loading/empty/error states, and cursor-based load-more behavior. Use the four prototype filters: Pendientes, Agendadas, Vencidas, Canceladas; render API `closed` in the terminal/cancelled group with a `Cerrada` chip.

- [ ] **Step 2: Build detail.** Show client/contact metadata, deposit/payment reference, restrictions, preferences, token expiry, audit-safe lifecycle information, and responsive actions. Never show token hashes or public token secrets.

- [ ] **Step 3: Implement lifecycle actions.** Use confirmation sheets/dialogs for revoke and close; on renew call the API and navigate through the same ephemeral link-ready handoff; handle conflicts, expired links, and `401` without optimistic state that can contradict the server.

- [ ] **Step 4: Test UI state coverage.** Cover filters, status rendering, pagination, empty state, detail loading, admin-only payment reference, close/revoke confirmation, renew navigation, API conflicts, and responsive shell integration.

- [ ] **Step 5: Record SDD progress and commit.** Update `context/tasks/backlog.md` with the completed T-011 evidence and leave T-012/T-013 unchanged. Then run:

```bash
cd app
fvm dart format lib test
fvm flutter test
fvm flutter analyze
cd ../api
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm test -- --runInBand --watchman=false
env PATH=/Users/jorge/.nvm/versions/node/v24.5.0/bin:$PATH npm run build
git diff --check
git add ../app ../context/tasks/backlog.md
git commit -m "feat(app): complete admin booking requests flow"
```

## Task 7: Run the local integration gate and document handoff

**Files:**

- Modify only if verification exposes a required correction: the files listed in Tasks 1–6.
- Do not add Docker, prototype files, PDF files, generated secrets, or committed `.env` values.

- [ ] **Step 1: Verify local prerequisites.** Confirm PostgreSQL is running, `api/.env` is present locally, Prisma reports the database up to date, and the Google Calendar credentials remain uncommitted. Do not print secret values.

- [ ] **Step 2: Run the complete gate.** From `api`, run migration status, unit tests, E2E tests, and build. From `app`, run `fvm flutter analyze`, all Flutter tests, and `fvm flutter build web --dart-define=API_BASE_URL=http://localhost:3000/v1`.

- [ ] **Step 3: Inspect the final diff.** Run `git diff --check`, `git status --short`, confirm only `app`, `api`, and `context` contain product changes, and confirm reference prototype/PDF files are not staged. If this task changes source/docs to fix a gate failure, make one focused follow-up commit with the appropriate Conventional Commit message; otherwise create no empty commit.

- [ ] **Step 4: Report handoff.** Summarize completed commits, commands and results, local startup commands, any database prerequisite, and the exact remaining backlog slice. Do not push to `origin` in this plan; remote publication is a separate explicit action.

## Definition of Done

- T-011 flows work against the local NestJS/PostgreSQL API: login, create request, copy/share link, list, detail, renew, revoke, and close.
- Contact channel/payment reference data is persisted additively and never leaks through public reservation responses.
- Admin routing is protected, session state is ephemeral, and raw tokens are never placed in URLs or storage.
- Flutter tests, Flutter analyzer, API tests, API build, Prisma migration status, and web build pass locally.
- The implementation preserves the approved prototype visual system and introduces no unapproved product scope.
- SDD design, plan, backlog evidence, and focused Conventional Commits are present under `context` and Git history.
