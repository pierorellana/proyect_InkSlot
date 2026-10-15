import { google, type calendar_v3 } from 'googleapis';

import type { CalendarConfig } from './calendar.config';
import {
  CalendarProviderError,
  type CalendarBusyQuery,
  type CalendarProviderErrorCode,
} from './calendar.provider';
import { GoogleCalendarProvider } from './google-calendar.provider';

describe('GoogleCalendarProvider.freeBusy', () => {
  const config: CalendarConfig = {
    configured: true,
    clientId: 'test-client-id',
    clientSecret: 'test-client-secret',
    redirectUri: 'http://localhost:3000/v1/admin/calendar/callback',
    calendarName: 'InkSlot',
    scopes: ['https://www.googleapis.com/auth/calendar.freebusy'],
  };
  const input: CalendarBusyQuery = {
    refreshToken: 'test-refresh-token',
    calendarId: 'inkslot-id',
    timeMin: new Date('2026-10-23T00:00:00Z'),
    timeMax: new Date('2026-10-24T00:00:00Z'),
    timeZone: 'America/Guayaquil',
  };
  const rawMessage = `raw-google-error ${input.refreshToken}`;
  let provider: GoogleCalendarProvider;
  let query: jest.Mock<
    Promise<{ data: calendar_v3.Schema$FreeBusyResponse }>,
    [calendar_v3.Params$Resource$Freebusy$Query]
  >;

  beforeEach(() => {
    query = jest.fn<
      Promise<{ data: calendar_v3.Schema$FreeBusyResponse }>,
      [calendar_v3.Params$Resource$Freebusy$Query]
    >();
    query.mockResolvedValue({
      data: { calendars: { [input.calendarId]: { busy: [] } } },
    });
    jest.spyOn(google, 'calendar').mockReturnValue({
      freebusy: { query },
    } as never);
    provider = new GoogleCalendarProvider(config);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  async function expectSafeError(
    code: CalendarProviderErrorCode,
  ): Promise<void> {
    const error: unknown = await provider
      .freeBusy(input)
      .catch((failure: unknown) => failure);
    expect(error).toBeInstanceOf(CalendarProviderError);
    if (!(error instanceof CalendarProviderError)) {
      throw new Error('Expected a CalendarProviderError');
    }
    expect(error.code).toBe(code);
    expect(error.message).not.toContain(input.refreshToken);
    expect(error.message).not.toContain('raw-google-error');
  }

  it('queries only the selected calendar with an explicit range and timezone', async () => {
    query.mockResolvedValue({
      data: {
        calendars: {
          [input.calendarId]: {
            busy: [
              {
                start: '2026-10-23T15:00:00Z',
                end: '2026-10-23T18:00:00Z',
              },
            ],
          },
          primary: {
            busy: [
              {
                start: '2026-10-23T00:00:00Z',
                end: '2026-10-24T00:00:00Z',
              },
            ],
          },
        },
      },
    });
    const setCredentials = jest.spyOn(
      google.auth.OAuth2.prototype,
      'setCredentials',
    );

    await expect(provider.freeBusy(input)).resolves.toEqual([
      {
        startAt: new Date('2026-10-23T15:00:00Z'),
        endAt: new Date('2026-10-23T18:00:00Z'),
      },
    ]);
    expect(setCredentials).toHaveBeenCalledWith({
      refresh_token: input.refreshToken,
    });
    expect(google.calendar).toHaveBeenCalledTimes(1);
    const [calendarOptions] = jest.mocked(google.calendar).mock.calls[0];
    expect(calendarOptions.version).toBe('v3');
    expect(calendarOptions.auth).toBeInstanceOf(google.auth.OAuth2);
    expect(query).toHaveBeenCalledTimes(1);
    expect(query).toHaveBeenCalledWith({
      requestBody: {
        timeMin: '2026-10-23T00:00:00.000Z',
        timeMax: '2026-10-24T00:00:00.000Z',
        timeZone: 'America/Guayaquil',
        items: [{ id: input.calendarId }],
      },
    });
  });

  it('normalizes offsets to UTC and sorts without changing interval boundaries', async () => {
    query.mockResolvedValue({
      data: {
        calendars: {
          [input.calendarId]: {
            busy: [
              {
                start: '2026-10-23T13:00:00-05:00',
                end: '2026-10-23T14:00:00-05:00',
              },
              {
                start: '2026-10-23T10:00:00-05:00',
                end: '2026-10-23T13:00:00-05:00',
              },
            ],
          },
        },
      },
    });

    await expect(provider.freeBusy(input)).resolves.toEqual([
      {
        startAt: new Date('2026-10-23T15:00:00Z'),
        endAt: new Date('2026-10-23T18:00:00Z'),
      },
      {
        startAt: new Date('2026-10-23T18:00:00Z'),
        endAt: new Date('2026-10-23T19:00:00Z'),
      },
    ]);
  });

  it.each([{}, { busy: [] }])(
    'returns no intervals for a successful empty calendar: %j',
    async (calendarData) => {
      query.mockResolvedValue({
        data: { calendars: { [input.calendarId]: calendarData } },
      });

      await expect(provider.freeBusy(input)).resolves.toEqual([]);
    },
  );

  it('rejects calendar-level errors even when busy intervals are present', async () => {
    query.mockResolvedValue({
      data: {
        calendars: {
          [input.calendarId]: {
            errors: [{ domain: 'calendar', reason: rawMessage }],
            busy: [
              { start: '2026-10-23T15:00:00Z', end: '2026-10-23T18:00:00Z' },
            ],
          },
        },
      },
    });

    await expectSafeError('CALENDAR_UNAVAILABLE');
  });

  it.each([{}, { calendars: {} }, { calendars: { primary: { busy: [] } } }])(
    'rejects a response missing the selected calendar: %j',
    async (data) => {
      query.mockResolvedValue({ data });

      await expectSafeError('CALENDAR_UNAVAILABLE');
    },
  );

  it.each([
    {},
    { end: '2026-10-23T18:00:00Z' },
    { start: '2026-10-23T15:00:00Z' },
    { start: null, end: '2026-10-23T18:00:00Z' },
    { start: '2026-10-23T15:00:00Z', end: null },
    { start: 'invalid', end: '2026-10-23T18:00:00Z' },
    { start: '2026-10-23T15:00:00Z', end: 'invalid' },
    { start: '2026-10-23T18:00:00Z', end: '2026-10-23T15:00:00Z' },
    { start: '2026-10-23T15:00:00Z', end: '2026-10-23T15:00:00Z' },
  ])(
    'rejects the entire response for an invalid interval: %j',
    async (busy) => {
      query.mockResolvedValue({
        data: {
          calendars: {
            [input.calendarId]: {
              busy: [
                { start: '2026-10-23T10:00:00Z', end: '2026-10-23T11:00:00Z' },
                busy,
              ],
            },
          },
        },
      });

      await expectSafeError('CALENDAR_UNAVAILABLE');
    },
  );

  it.each([
    { response: { status: 401 } },
    { response: { status: 403 } },
    { code: 401 },
    { code: 403 },
  ])('requires reauthorization for a numeric HTTP error: %j', async (error) => {
    query.mockRejectedValue({ ...error, message: rawMessage });

    await expectSafeError('CALENDAR_REAUTH_REQUIRED');
  });

  it.each([
    { response: { status: 500 } },
    { response: { status: 429 } },
    { code: '401' },
    { code: 'ECONNRESET' },
    {},
    null,
  ])(
    'maps other provider failures to a safe unavailable error: %j',
    async (error) => {
      query.mockRejectedValue(
        error === null ? null : { ...error, message: rawMessage },
      );

      await expectSafeError('CALENDAR_UNAVAILABLE');
    },
  );

  it.each(['configured', 'clientId', 'clientSecret', 'redirectUri'] as const)(
    'rejects missing configuration before accessing Calendar: %s',
    async (field) => {
      provider = new GoogleCalendarProvider({
        ...config,
        [field]: field === 'configured' ? false : undefined,
      });

      await expectSafeError('CALENDAR_NOT_CONFIGURED');
      expect(google.calendar).not.toHaveBeenCalled();
      expect(query).not.toHaveBeenCalled();
    },
  );
});
