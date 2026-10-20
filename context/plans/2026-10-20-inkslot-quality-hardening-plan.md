# InkSlot quality hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute each task as a focused vertical slice with tests and a small commit.

**Goal:** Corregir las regresiones Flutter, cerrar la configuración de seguridad y observabilidad del API, declarar el calendario del cliente como futuro y sincronizar el SDD.

**Architecture:** Las pruebas Flutter recibirán fechas estables desde sus fixtures en lugar de leer fechas implícitas del reloj. NestJS aplicará CORS, headers, validación de origen, rate limits y request IDs en los bordes HTTP; los servicios de dominio conservarán sus contratos actuales. La documentación se actualizará después de verificar el código.

**Tech Stack:** Flutter Web 3.47.5/FVM, Dart, NestJS 11, TypeScript, `@nestjs/throttler`, PostgreSQL/Prisma y documentación SDD existente en `context/`.

## Global Constraints

- El workspace mantiene únicamente `app/`, `api/` y `context/` como carpetas principales.
- PostgreSQL se ejecuta localmente; no se agrega Docker.
- No se guardan secretos ni credenciales reales en el repositorio.
- Los tests deben verificar comportamiento observable y conservar los estados visuales existentes.
- “Guardar en mi calendario” queda como funcionalidad futura y no puede aparentar una acción completada.

### Task 1: Stabilize Flutter regression fixtures

**Files:**
- Modify: `app/test/tool/client_shots_test.dart`
- Modify: `app/test/tool/client_shots_support.dart` only if a reusable first-day helper is needed
- Modify: `app/test/features/appointments/admin_appointment_detail_test.dart`
- Modify: `app/lib/features/appointments/presentation/admin_appointment_detail_page.dart` only if the failing repro proves a production interaction bug

**Verification:**

- Run the focused client shots and appointment detail tests.
- Run the complete Flutter test suite and record any failures that are unrelated to this slice.

### Task 2: Harden API edge security

**Files:**
- Modify: `api/src/main.ts`
- Modify: `api/src/app.module.ts`
- Create or modify: `api/src/security/*` for origin validation and security configuration
- Modify: affected auth, public reservation and confirmation controllers for route-specific throttles
- Modify: `api/.env.example`
- Test: `api/src/security/*.spec.ts` and affected controller specs

**Verification:**

- Allowed origins receive CORS headers and disallowed origins do not.
- Credentialed requests never use wildcard/reflected origins.
- Cross-origin administrative mutations without an allowed origin are rejected.
- Login, public resolution and public confirmation have their specific limits.
- Security headers are present in HTTP responses.

### Task 3: Add request IDs and structured request logging

**Files:**
- Create: `api/src/observability/request-id.middleware.ts`
- Create: `api/src/observability/observability.module.ts` if the middleware needs module registration
- Modify: `api/src/main.ts` or `api/src/app.module.ts` to register the middleware
- Modify: global error handling so the response error contains `requestId`
- Test: `api/src/observability/request-id.middleware.spec.ts` and HTTP error behavior

**Verification:**

- A valid incoming `X-Request-Id` is preserved.
- Missing or malformed IDs are replaced with a generated UUID.
- Every response returns `X-Request-Id`.
- Validation and domain errors expose the same request ID.
- Logs contain request ID, method, path, status and duration without client contact data.

### Task 4: Mark client calendar save as future

**Files:**
- Modify: `app/lib/features/public_booking/presentation/public_result_page.dart`
- Modify: `app/test/features/public_booking/public_result_page_test.dart`
- Modify: relevant public experience and acceptance documentation

**Verification:**

- The control is visibly marked as future and cannot claim an event was created.
- Existing confirmation/result states remain unchanged.

### Task 5: Synchronize SDD documentation

**Files:**
- Modify: `context/adr/ADR-002-booking-integrity-and-calendar.md`
- Modify: `context/adr/ADR-003-auth-and-public-tokens.md`
- Modify: `context/architecture/solution.md`
- Modify: `context/architecture/api-contracts.md`
- Modify: affected files under `context/specs/`, `context/plans/`, `context/tasks/backlog.md`, `context/quality/acceptance-matrix.md` and `context/quality/visual-parity.md`

**Verification:**

- No implemented endpoint remains described only as a proposal.
- The removed Agenda rules UI and removed public timezone/studio copy are recorded as deliberate decisions.
- Security, request IDs, future calendar save and known test limitations are traceable.
- `git diff --check` passes.

### Task 6: Commit and release gate

- Run focused tests, full tests, analyzer, API build/tests and documentation checks.
- Separate commits by Flutter regression, API security, observability, public future capability and SDD updates.
- Do not claim production readiness while environment-dependent test gates remain unresolved.
