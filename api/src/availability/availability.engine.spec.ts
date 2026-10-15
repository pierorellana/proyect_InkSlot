import {
  AvailabilityEngine,
  CalendarUnavailableError,
  type AvailabilityInput,
} from './availability.engine';

const baseInput = (): AvailabilityInput => ({
  timezone: 'America/Guayaquil',
  fromDate: '2026-10-20',
  toDate: '2026-10-20',
  now: new Date('2026-10-19T12:00:00.000Z'),
  durationMinutes: 180,
  slotStepMinutes: 30,
  minimumNoticeHours: 0,
  horizonDays: 60,
  bufferMinutes: 0,
  weeklyWindows: [{ weekday: 2, startLocal: '10:00', endLocal: '20:00' }],
  internalBlocks: [],
  internalBusy: [],
  externalBusy: [],
  calendarVerifiable: true,
});

describe('AvailabilityEngine', () => {
  const engine = new AvailabilityEngine();

  it('does not offer a session that cannot fit in the working window', () => {
    const input = baseInput();
    input.weeklyWindows = [
      { weekday: 2, startLocal: '10:00', endLocal: '12:00' },
    ];

    expect(engine.calculate(input)).toEqual({
      timezone: 'America/Guayaquil',
      days: [],
    });
  });

  it('keeps the half-open boundaries around a lunch pause and returns UTC slots', () => {
    const input = baseInput();
    input.weeklyWindows = [
      { weekday: 2, startLocal: '10:00', endLocal: '13:30' },
      { weekday: 2, startLocal: '14:30', endLocal: '20:00' },
    ];

    const result = engine.calculate(input);

    expect(result.days).toHaveLength(1);
    expect(result.days[0]?.date).toBe('2026-10-20');
    expect(result.days[0]?.slots).toEqual([
      {
        startAt: '2026-10-20T15:00:00.000Z',
        endAt: '2026-10-20T18:00:00.000Z',
      },
      {
        startAt: '2026-10-20T15:30:00.000Z',
        endAt: '2026-10-20T18:30:00.000Z',
      },
      {
        startAt: '2026-10-20T19:30:00.000Z',
        endAt: '2026-10-20T22:30:00.000Z',
      },
      {
        startAt: '2026-10-20T20:00:00.000Z',
        endAt: '2026-10-20T23:00:00.000Z',
      },
      {
        startAt: '2026-10-20T20:30:00.000Z',
        endAt: '2026-10-20T23:30:00.000Z',
      },
      {
        startAt: '2026-10-20T21:00:00.000Z',
        endAt: '2026-10-21T00:00:00.000Z',
      },
      {
        startAt: '2026-10-20T21:30:00.000Z',
        endAt: '2026-10-21T00:30:00.000Z',
      },
      {
        startAt: '2026-10-20T22:00:00.000Z',
        endAt: '2026-10-21T01:00:00.000Z',
      },
    ]);
  });

  it('removes internal blocks, external occupancy, and applies the buffer', () => {
    const input = baseInput();
    input.internalBlocks = [
      {
        startAt: new Date('2026-10-20T16:30:00.000Z'),
        endAt: new Date('2026-10-20T17:30:00.000Z'),
      },
    ];
    input.externalBusy = [
      {
        startAt: new Date('2026-10-20T19:00:00.000Z'),
        endAt: new Date('2026-10-20T21:00:00.000Z'),
      },
    ];
    input.bufferMinutes = 30;

    const slots = engine.calculate(input).days[0]?.slots ?? [];

    expect(slots).toEqual([
      {
        startAt: '2026-10-20T21:30:00.000Z',
        endAt: '2026-10-21T00:30:00.000Z',
      },
      {
        startAt: '2026-10-20T22:00:00.000Z',
        endAt: '2026-10-21T01:00:00.000Z',
      },
    ]);
  });

  it('applies request weekday, date, and local-window restrictions', () => {
    const input = baseInput();
    input.toDate = '2026-10-21';
    input.weeklyWindows = [
      { weekday: 2, startLocal: '10:00', endLocal: '20:00' },
      { weekday: 3, startLocal: '10:00', endLocal: '20:00' },
    ];
    input.request = {
      allowedWeekdays: [3],
      minDate: '2026-10-21',
      maxDate: '2026-10-21',
      allowedWindows: [{ startLocal: '12:00', endLocal: '15:00' }],
    };

    const result = engine.calculate(input);

    expect(result.days).toHaveLength(1);
    expect(result.days[0]?.slots).toEqual([
      {
        startAt: '2026-10-21T17:00:00.000Z',
        endAt: '2026-10-21T20:00:00.000Z',
      },
    ]);
  });

  it('applies minimum notice and horizon using the study timezone', () => {
    const input = baseInput();
    input.toDate = '2026-11-01';
    input.weeklyWindows = [
      { weekday: 2, startLocal: '10:00', endLocal: '20:00' },
      { weekday: 3, startLocal: '10:00', endLocal: '20:00' },
    ];
    input.minimumNoticeHours = 48;
    input.horizonDays = 3;

    const result = engine.calculate(input);

    expect(result.days.map((day) => day.date)).toEqual(['2026-10-21']);
  });

  it('materializes local windows correctly across an IANA DST transition', () => {
    const input = baseInput();
    input.timezone = 'America/New_York';
    input.fromDate = '2026-11-01';
    input.toDate = '2026-11-01';
    input.now = new Date('2026-10-31T12:00:00.000Z');
    input.weeklyWindows = [
      { weekday: 0, startLocal: '10:00', endLocal: '13:00' },
    ];

    expect(engine.calculate(input).days[0]?.slots).toEqual([
      {
        startAt: '2026-11-01T15:00:00.000Z',
        endAt: '2026-11-01T18:00:00.000Z',
      },
    ]);
  });

  it('fails closed when Calendar cannot be verified', () => {
    const input = baseInput();
    input.calendarVerifiable = false;

    expect(() => engine.calculate(input)).toThrow(CalendarUnavailableError);
    expect(() => engine.calculate(input)).toThrow('CALENDAR_UNAVAILABLE');
  });
});
