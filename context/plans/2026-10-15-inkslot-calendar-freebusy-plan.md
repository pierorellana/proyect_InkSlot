# Calendar freeBusy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use the project SDD conventions in `context/00-governance/AGENTS.md` and implement one task at a time with a focused commit.

**Goal:** Connect the persisted Google Calendar OAuth connection to a safe, testable `freeBusy` query that returns external busy intervals in UTC.

**Architecture:** Extend the existing `CalendarProvider` boundary with a typed `freeBusy` operation. `GoogleCalendarProvider` owns the Google API request and maps provider failures to safe domain errors; `CalendarService` owns connection lookup, token decryption, reconnect state transitions, and HTTP-safe error mapping. `AvailabilityEngine` remains pure and will consume the returned intervals in a later slice.

**Tech Stack:** NestJS 11, TypeScript, Prisma 6, PostgreSQL local, `googleapis` Calendar v3, Luxon, Jest, Supertest.

## Global Constraints

- Keep workspace roots limited to `app`, `api`, and `context`.
- Use local PostgreSQL and Prisma; do not add Docker or external infrastructure.
- Keep refresh tokens encrypted in PostgreSQL and never return or log them.
- Use the existing `/v1` prefix, safe error envelope, `CalendarCrypto`, `CalendarProvider`, and `CalendarService` boundaries.
- Query only the selected `CalendarConnection.calendarId`; never fall back to `primary` or another calendar.
- Send `timeMin`, `timeMax`, `timeZone`, and `items: [{ id: calendarId }]` explicitly to Google.
- Preserve RFC3339 and semi-open interval semantics: busy start inclusive, busy end exclusive.
- A missing, non-connected, malformed, or unavailable Calendar connection fails closed with `503 CALENDAR_UNAVAILABLE`.
- A Google authorization failure marks the connection `NEEDS_RECONNECT` before returning the safe unavailable error.
- Do not create the public availability endpoint, booking-token logic, event synchronization, outbox, worker, or Flutter UI in this plan.
- Every task ends with focused tests, formatting/lint/build verification where relevant, and a small Conventional Commit.

## File Map

Modify:

- `api/src/calendar/calendar.provider.ts` — add freeBusy input/output types and provider error code.
- `api/src/calendar/google-calendar.provider.ts` — call Google `calendar.freebusy.query` and normalize the response.
- `api/src/calendar/calendar.service.ts` — add the persisted-connection freeBusy use case and reconnect transition.
- `api/test/calendar.e2e-spec.ts` — extend the fake provider and verify the service against PostgreSQL local.
- `context/tasks/backlog.md` — record the completed freeBusy adapter/service portion of T-009.

Create:

- `api/src/calendar/google-calendar.provider.spec.ts` — verify the Google adapter request, response mapping, and provider errors.
- `api/src/calendar/calendar.service.spec.ts` — verify service validation and safe error/state behavior with focused mocks.

## Task 1: Add the freeBusy provider contract and Google adapter

**Files:**

- Modify: `api/src/calendar/calendar.provider.ts`
- Modify: `api/src/calendar/google-calendar.provider.ts`
- Create: `api/src/calendar/google-calendar.provider.spec.ts`

**Interfaces:**

```ts
export type CalendarBusyQuery = {
  refreshToken: string;
  calendarId: string;
  timeMin: Date;
  timeMax: Date;
  timeZone: string;
};

export type CalendarBusyInterval = {
  startAt: Date;
  endAt: Date;
};

export type CalendarProviderErrorCode =
  | 'CALENDAR_NOT_CONFIGURED'
  | 'CALENDAR_UNAVAILABLE'
  | 'CALENDAR_REAUTH_REQUIRED'
  | 'OAUTH_ACCESS_DENIED';

export interface CalendarProvider {
  authorizationUrl(input: { state: string }): string;
  exchangeCode(code: string): Promise<CalendarTokens>;
  listCalendars(refreshToken: string): Promise<CalendarSummary[]>;
  freeBusy(input: CalendarBusyQuery): Promise<CalendarBusyInterval[]>;
  revoke(refreshToken: string): Promise<void>;
}
```

- [ ] **Step 1: Add contract types and the reconnect error code**

Update `calendar.provider.ts` with the exact types and method above. Keep existing OAuth methods unchanged. The new provider error code is internal and will be translated by `CalendarService`; it must never be emitted as a raw Google message.

- [ ] **Step 2: Write failing adapter tests**

Create `google-calendar.provider.spec.ts` with a mocked `google.calendar` resource. The first test must assert the exact request and normalized response:

```ts
it('queries only the selected calendar with an explicit range and timezone', async () => {
  const query = jest.fn().mockResolvedValue({
    data: {
      calendars: {
        'inkslot-id': {
          busy: [
            {
              start: '2026-10-23T15:00:00Z',
              end: '2026-10-23T18:00:00Z',
            },
          ],
        },
      },
    },
  });
  jest.spyOn(google, 'calendar').mockReturnValue({
    freebusy: { query },
  } as never);

  const provider = new GoogleCalendarProvider(configuredCalendarConfig);
  await expect(
    provider.freeBusy({
      refreshToken: 'refresh-token',
      calendarId: 'inkslot-id',
      timeMin: new Date('2026-10-23T00:00:00Z'),
      timeMax: new Date('2026-10-24T00:00:00Z'),
      timeZone: 'America/Guayaquil',
    }),
  ).resolves.toEqual([
    {
      startAt: new Date('2026-10-23T15:00:00Z'),
      endAt: new Date('2026-10-23T18:00:00Z'),
    },
  ]);

  expect(query).toHaveBeenCalledWith({
    requestBody: {
      timeMin: '2026-10-23T00:00:00.000Z',
      timeMax: '2026-10-24T00:00:00.000Z',
      timeZone: 'America/Guayaquil',
      items: [{ id: 'inkslot-id' }],
    },
  });
});
```

Add tests for a calendar-level response error, malformed or inverted busy intervals, HTTP 401/403 authorization errors, and an unconfigured provider. Each test must assert a `CalendarProviderError` code and must not expose the refresh token in the error message.

Mock `google.calendar` and restore all spies after each test. Do not make HTTP requests.

- [ ] **Step 3: Run the focused tests and verify the red state**

Run from `api`:

```bash
npm test -- --runInBand --watchman=false src/calendar/google-calendar.provider.spec.ts
```

Expected: FAIL because `freeBusy` and its implementation do not exist yet.

- [ ] **Step 4: Implement `GoogleCalendarProvider.freeBusy`**

Use the existing `createClient()` and refresh-token setup pattern:

```ts
async freeBusy(input: CalendarBusyQuery): Promise<CalendarBusyInterval[]> {
  try {
    const client = this.createClient();
    client.setCredentials({ refresh_token: input.refreshToken });
    const calendar = google.calendar({ version: 'v3', auth: client });
    const response = await calendar.freebusy.query({
      requestBody: {
        timeMin: input.timeMin.toISOString(),
        timeMax: input.timeMax.toISOString(),
        timeZone: input.timeZone,
        items: [{ id: input.calendarId }],
      },
    });
    const calendarData = response.data.calendars?.[input.calendarId];
    if (!calendarData || (calendarData.errors?.length ?? 0) > 0) {
      throw new CalendarProviderError(
        'CALENDAR_UNAVAILABLE',
        'No fue posible consultar la disponibilidad de Google',
      );
    }

    return (calendarData.busy ?? [])
      .map((busy) => {
        const startAt = new Date(busy.start ?? '');
        const endAt = new Date(busy.end ?? '');
        if (
          !busy.start ||
          !busy.end ||
          !Number.isFinite(startAt.getTime()) ||
          !Number.isFinite(endAt.getTime()) ||
          startAt.getTime() >= endAt.getTime()
        ) {
          throw new CalendarProviderError(
            'CALENDAR_UNAVAILABLE',
            'Google devolvió un intervalo de disponibilidad inválido',
          );
        }
        return { startAt, endAt };
      })
      .sort((left, right) => left.startAt.getTime() - right.startAt.getTime());
  } catch (error) {
    if (error instanceof CalendarProviderError) throw error;
    const status = this.googleHttpStatus(error);
    if (status === 401 || status === 403) {
      throw new CalendarProviderError(
        'CALENDAR_REAUTH_REQUIRED',
        'La conexión de Google requiere autorización nuevamente',
      );
    }
    throw new CalendarProviderError(
      'CALENDAR_UNAVAILABLE',
      'No fue posible consultar la disponibilidad de Google',
    );
  }
}
```

The helper used by the implementation may inspect only the numeric HTTP status from the Google error object. It must not include the original error text in a thrown message. Preserve the existing `listCalendars` and `revoke` behavior.

- [ ] **Step 5: Run adapter tests and commit**

Run:

```bash
npm test -- --runInBand --watchman=false src/calendar/google-calendar.provider.spec.ts
npm run build
```

Expected: all adapter tests and the build pass. Commit:

```bash
git add api/src/calendar/calendar.provider.ts api/src/calendar/google-calendar.provider.ts api/src/calendar/google-calendar.provider.spec.ts
git commit -m "feat(api): add calendar freebusy provider"
```

## Task 2: Add the persisted-connection service use case

**Files:**

- Modify: `api/src/calendar/calendar.service.ts`
- Create: `api/src/calendar/calendar.service.spec.ts`

**Interfaces:**

```ts
export type CalendarBusyQueryInput = {
  timeMin: Date;
  timeMax: Date;
  timeZone: string;
};

queryBusy(
  artistId: string,
  input: CalendarBusyQueryInput,
): Promise<CalendarBusyInterval[]>;
```

- [ ] **Step 1: Write focused service tests**

Instantiate `CalendarService` with typed partial mocks for Prisma, state, crypto, provider, and config. Cover these cases:

```ts
it('decrypts the stored token and queries the selected connected calendar', async () => {
  prisma.calendarConnection.findUnique.mockResolvedValue({
    artistId: 'artist-id',
    calendarId: 'inkslot-id',
    encryptedRefreshToken: 'encrypted-token',
    status: CalendarConnectionStatus.CONNECTED,
  });
  crypto.decrypt.mockReturnValue('refresh-token');
  provider.freeBusy.mockResolvedValue([
    {
      startAt: new Date('2026-10-23T15:00:00Z'),
      endAt: new Date('2026-10-23T18:00:00Z'),
    },
  ]);

  await expect(
    service.queryBusy('artist-id', {
      timeMin: new Date('2026-10-23T00:00:00Z'),
      timeMax: new Date('2026-10-24T00:00:00Z'),
      timeZone: 'America/Guayaquil',
    }),
  ).resolves.toHaveLength(1);
  expect(crypto.decrypt).toHaveBeenCalledWith('encrypted-token');
  expect(provider.freeBusy).toHaveBeenCalledWith({
    refreshToken: 'refresh-token',
    calendarId: 'inkslot-id',
    timeMin: new Date('2026-10-23T00:00:00Z'),
    timeMax: new Date('2026-10-24T00:00:00Z'),
    timeZone: 'America/Guayaquil',
  });
});
```

Also cover no connection, `NEEDS_RECONNECT`, an invalid date range/timezone, a normal provider outage, a `CALENDAR_REAUTH_REQUIRED` provider error that calls `markNeedsReconnect`, and a decryption failure. Every failure must be a `ServiceUnavailableException` with `{ error: { code: 'CALENDAR_UNAVAILABLE', message: expect.any(String) } }`, except the existing configuration error behavior.

- [ ] **Step 2: Run the focused tests to verify the red state**

Run:

```bash
npm test -- --runInBand --watchman=false src/calendar/calendar.service.spec.ts
```

Expected: FAIL because `queryBusy` is not implemented.

- [ ] **Step 3: Implement input validation and connection lookup**

Add the exported input type and method to `CalendarService`. Before calling the provider, reject invalid `Date` values, `timeMin >= timeMax`, and invalid IANA zones with a safe `ServiceUnavailableException`. Load the connection with:

```ts
const connection = await this.prisma.calendarConnection.findUnique({
  where: { artistId },
});
if (!connection || connection.status !== CalendarConnectionStatus.CONNECTED) {
  throw new ServiceUnavailableException(
    safeError(
      'CALENDAR_UNAVAILABLE',
      'No fue posible verificar la disponibilidad del calendario',
    ),
  );
}
```

Do not call `freeBusy` for a missing or non-connected row.

- [ ] **Step 4: Implement decryption, provider delegation, and reconnect handling**

Use `CalendarCrypto.decrypt(connection.encryptedRefreshToken)` and delegate exactly the selected calendar and input range. Catch `CalendarProviderError`; when its code is `CALENDAR_REAUTH_REQUIRED`, call the existing `markNeedsReconnect(artistId)` before translating the error. Translate all provider/decryption/unexpected errors to the existing safe `503 CALENDAR_UNAVAILABLE` envelope without including the original error text.

Keep `markNeedsReconnect` idempotent with the existing `updateMany` implementation. Do not delete the connection or appointments after a freeBusy error.

- [ ] **Step 5: Run service tests, lint, and commit**

Run:

```bash
npm test -- --runInBand --watchman=false src/calendar/calendar.service.spec.ts
npm run lint
npm run build
```

Expected: focused tests pass, lint has no errors, and the API builds. Commit:

```bash
git add api/src/calendar/calendar.service.ts api/src/calendar/calendar.service.spec.ts
git commit -m "feat(api): query calendar busy intervals"
```

## Task 3: Verify module integration and update SDD evidence

**Files:**

- Modify: `api/test/calendar.e2e-spec.ts`
- Modify: `context/tasks/backlog.md`

**Interfaces:**

- The E2E fake provider implements `freeBusy(input: CalendarBusyQuery): Promise<CalendarBusyInterval[]>`.
- The test obtains `CalendarService` from the Nest application and calls `queryBusy` with a real persisted `CalendarConnection`.

- [ ] **Step 1: Extend the fake provider and add the integration test**

Add `freeBusy: jest.fn()` to the existing fake provider. Add a test that creates a `CONNECTED` `CalendarConnection` for the seeded artist, configures the fake provider with one busy interval, calls `app.get(CalendarService).queryBusy(...)`, and asserts the interval plus the exact provider input. Assert that the fake crypto receives the encrypted database value and that the returned data contains no token.

Add a second test where `freeBusy` rejects with `new CalendarProviderError('CALENDAR_REAUTH_REQUIRED', 'provider detail')`; assert that the service throws `ServiceUnavailableException`, the database row becomes `NEEDS_RECONNECT`, and neither the token nor provider detail appears in the serialized exception.

Delete the connection in `beforeEach` as the existing suite already does. Do not add a new HTTP endpoint for this internal service operation.

- [ ] **Step 2: Update backlog evidence**

Change T-009 in `context/tasks/backlog.md` to state that OAuth connection plus the `freeBusy` provider/service and reconnect transition are implemented. Leave public availability orchestration, event CRUD, outbox, retries, sync issues, and Flutter Calendar UI explicitly pending.

- [ ] **Step 3: Run the complete API verification**

Run from `api`:

```bash
npm test -- --runInBand --watchman=false
npm run test:e2e -- --runInBand --watchman=false
npm run lint
npm run build
```

Expected: all unit tests, all E2E suites, lint, and build pass using local PostgreSQL. No test may call Google or print a credential.

- [ ] **Step 4: Commit the integration evidence**

```bash
git add api/test/calendar.e2e-spec.ts context/tasks/backlog.md
git commit -m "test(api): verify calendar freebusy integration"
```

## Self-review checklist

- Spec coverage: provider payload, UTC interval mapping, safe failures, reconnect transition, local PostgreSQL integration, and SDD backlog evidence are covered by Tasks 1–3.
- Placeholder scan: this plan contains no `TBD`, `TODO`, or unspecified implementation step.
- Type consistency: `CalendarBusyQuery`, `CalendarBusyInterval`, `CalendarBusyQueryInput`, `freeBusy`, and `queryBusy` names are used consistently across all tasks.
- Scope check: the plan contains only the approved backend freeBusy slice; the public endpoint and Flutter work remain separate.
