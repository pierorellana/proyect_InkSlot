import { DateTime } from 'luxon';

export type AvailabilityWindow = {
  weekday: number;
  startLocal: string;
  endLocal: string;
};

export type LocalWindowRestriction = {
  startLocal: string;
  endLocal: string;
};

export type AvailabilityInterval = {
  startAt: Date;
  endAt: Date;
};

export type AvailabilityRequest = {
  allowedWeekdays?: number[];
  minDate?: string;
  maxDate?: string;
  allowedWindows?: LocalWindowRestriction[];
};

export type AvailabilityInput = {
  timezone: string;
  fromDate: string;
  toDate: string;
  now: Date;
  durationMinutes: number;
  slotStepMinutes: number;
  minimumNoticeHours: number;
  horizonDays: number;
  bufferMinutes: number;
  weeklyWindows: AvailabilityWindow[];
  internalBlocks: AvailabilityInterval[];
  internalBusy: AvailabilityInterval[];
  externalBusy: AvailabilityInterval[];
  calendarVerifiable: boolean;
  request?: AvailabilityRequest;
};

export type AvailabilitySlot = {
  startAt: string;
  endAt: string;
};

export type AvailabilityDay = {
  date: string;
  slots: AvailabilitySlot[];
};

export type AvailabilityResult = {
  timezone: string;
  days: AvailabilityDay[];
};

export class CalendarUnavailableError extends Error {
  readonly code = 'CALENDAR_UNAVAILABLE';

  constructor() {
    super('CALENDAR_UNAVAILABLE');
    this.name = 'CalendarUnavailableError';
  }
}

export class AvailabilityInputError extends Error {
  readonly code = 'INVALID_AVAILABILITY_INPUT';

  constructor(message: string) {
    super(message);
    this.name = 'AvailabilityInputError';
  }
}

export class AvailabilityEngine {
  calculate(input: AvailabilityInput): AvailabilityResult {
    if (!input.calendarVerifiable) {
      throw new CalendarUnavailableError();
    }

    this.validateInput(input);

    const from = this.parseDate(input.fromDate, input.timezone).startOf('day');
    const to = this.parseDate(input.toDate, input.timezone).startOf('day');
    const now = DateTime.fromJSDate(input.now, { zone: input.timezone });
    const minimumStart = now.plus({ hours: input.minimumNoticeHours });
    const horizonEnd = now.plus({ days: input.horizonDays });
    const days: AvailabilityDay[] = [];

    for (
      let day = from;
      day.toMillis() <= to.toMillis();
      day = day.plus({ days: 1 })
    ) {
      const date = this.toDateString(day);
      const weekday = day.weekday % 7;

      if (!this.isRequestDateAllowed(input.request, date, weekday)) {
        continue;
      }

      const slots = this.slotsForDay(input, day, minimumStart, horizonEnd);
      if (slots.length > 0) {
        days.push({ date, slots });
      }
    }

    return { timezone: input.timezone, days };
  }

  private slotsForDay(
    input: AvailabilityInput,
    day: DateTime,
    minimumStart: DateTime,
    horizonEnd: DateTime,
  ): AvailabilitySlot[] {
    const weekday = day.weekday % 7;
    const requestWindows = input.request?.allowedWindows;
    const windows = input.weeklyWindows
      .filter((window) => window.weekday === weekday)
      .flatMap((window) => this.intersectWindows(window, requestWindows));
    const slots: AvailabilitySlot[] = [];
    const seen = new Set<string>();

    for (const window of windows) {
      const windowStart = this.localTime(day, window.startLocal);
      const windowEnd = this.localTime(day, window.endLocal);

      for (
        let start = windowStart;
        start.toMillis() + input.durationMinutes * 60_000 <=
        windowEnd.toMillis();
        start = start.plus({ minutes: input.slotStepMinutes })
      ) {
        const end = start.plus({ minutes: input.durationMinutes });
        if (
          start.toMillis() < minimumStart.toMillis() ||
          end.toMillis() > horizonEnd.toMillis()
        ) {
          continue;
        }

        const interval = {
          startAt: start.toUTC().toJSDate(),
          endAt: end.toUTC().toJSDate(),
        };
        if (
          this.overlapsAny(interval, input.internalBlocks) ||
          this.overlapsBufferedExternal(
            interval,
            input.internalBusy,
            input.bufferMinutes,
          ) ||
          this.overlapsBufferedExternal(
            interval,
            input.externalBusy,
            input.bufferMinutes,
          )
        ) {
          continue;
        }

        const slot = {
          startAt: this.toUtcIso(interval.startAt),
          endAt: this.toUtcIso(interval.endAt),
        };
        const key = `${slot.startAt}/${slot.endAt}`;
        if (!seen.has(key)) {
          seen.add(key);
          slots.push(slot);
        }
      }
    }

    return slots.sort((left, right) =>
      left.startAt.localeCompare(right.startAt),
    );
  }

  private intersectWindows(
    weeklyWindow: AvailabilityWindow,
    requestWindows: LocalWindowRestriction[] | undefined,
  ): AvailabilityWindow[] {
    if (!requestWindows || requestWindows.length === 0) {
      return [weeklyWindow];
    }

    const weeklyStart = this.clockToMinutes(weeklyWindow.startLocal);
    const weeklyEnd = this.clockToMinutes(weeklyWindow.endLocal);
    return requestWindows.flatMap((requestWindow) => {
      const start = Math.max(
        weeklyStart,
        this.clockToMinutes(requestWindow.startLocal),
      );
      const end = Math.min(
        weeklyEnd,
        this.clockToMinutes(requestWindow.endLocal),
      );
      if (start >= end) return [];

      return [
        {
          weekday: weeklyWindow.weekday,
          startLocal: this.minutesToClock(start),
          endLocal: this.minutesToClock(end),
        },
      ];
    });
  }

  private isRequestDateAllowed(
    request: AvailabilityRequest | undefined,
    date: string,
    weekday: number,
  ): boolean {
    if (!request) return true;
    if (request.allowedWeekdays && !request.allowedWeekdays.includes(weekday)) {
      return false;
    }
    if (request.minDate && date < request.minDate) return false;
    if (request.maxDate && date > request.maxDate) return false;
    return true;
  }

  private overlapsAny(
    interval: AvailabilityInterval,
    busy: AvailabilityInterval[],
  ): boolean {
    return busy.some(
      (occupied) =>
        interval.startAt.getTime() < occupied.endAt.getTime() &&
        interval.endAt.getTime() > occupied.startAt.getTime(),
    );
  }

  private overlapsBufferedExternal(
    interval: AvailabilityInterval,
    busy: AvailabilityInterval[],
    bufferMinutes: number,
  ): boolean {
    const bufferMs = bufferMinutes * 60_000;
    return busy.some((occupied) => {
      const buffered = {
        startAt: new Date(occupied.startAt.getTime() - bufferMs),
        endAt: new Date(occupied.endAt.getTime() + bufferMs),
      };
      return this.overlapsAny(interval, [buffered]);
    });
  }

  private validateInput(input: AvailabilityInput): void {
    if (!DateTime.now().setZone(input.timezone).isValid) {
      throw new AvailabilityInputError('Invalid IANA timezone');
    }
    const from = this.parseDate(input.fromDate, input.timezone);
    const to = this.parseDate(input.toDate, input.timezone);
    const now = DateTime.fromJSDate(input.now, { zone: input.timezone });
    if (!now.isValid) {
      throw new AvailabilityInputError('now must be a valid instant');
    }
    if (from.toMillis() > to.toMillis()) {
      throw new AvailabilityInputError('fromDate must be before toDate');
    }
    if (
      input.durationMinutes <= 0 ||
      input.slotStepMinutes <= 0 ||
      input.minimumNoticeHours < 0 ||
      input.horizonDays <= 0 ||
      input.bufferMinutes < 0
    ) {
      throw new AvailabilityInputError(
        'Scheduling parameters must be positive',
      );
    }
    for (const window of input.weeklyWindows) {
      if (window.weekday < 0 || window.weekday > 6) {
        throw new AvailabilityInputError('weekday must be between 0 and 6');
      }
      if (
        this.clockToMinutes(window.startLocal) >=
        this.clockToMinutes(window.endLocal)
      ) {
        throw new AvailabilityInputError(
          'Availability windows must be ordered',
        );
      }
    }
    for (const interval of [
      ...input.internalBlocks,
      ...input.internalBusy,
      ...input.externalBusy,
    ]) {
      if (interval.startAt.getTime() >= interval.endAt.getTime()) {
        throw new AvailabilityInputError('Intervals must be ordered');
      }
    }
  }

  private parseDate(value: string, timezone: string): DateTime {
    const date = DateTime.fromISO(value, { zone: timezone });
    if (!date.isValid || date.toISODate() !== value) {
      throw new AvailabilityInputError(`Invalid local date: ${value}`);
    }
    return date;
  }

  private localTime(day: DateTime, clock: string): DateTime {
    const minutes = this.clockToMinutes(clock);
    return DateTime.fromObject(
      {
        year: day.year,
        month: day.month,
        day: day.day,
        hour: Math.floor(minutes / 60),
        minute: minutes % 60,
      },
      { zone: day.zone },
    );
  }

  private clockToMinutes(clock: string): number {
    const match = /^(\d{2}):(\d{2})$/.exec(clock);
    if (!match) {
      throw new AvailabilityInputError(`Invalid local time: ${clock}`);
    }
    const hours = Number(match[1]);
    const minutes = Number(match[2]);
    if (hours > 23 || minutes > 59) {
      throw new AvailabilityInputError(`Invalid local time: ${clock}`);
    }
    return hours * 60 + minutes;
  }

  private minutesToClock(minutes: number): string {
    return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(
      minutes % 60,
    ).padStart(2, '0')}`;
  }

  private toDateString(day: DateTime): string {
    return day.toISODate() as string;
  }

  private toUtcIso(date: Date): string {
    return DateTime.fromJSDate(date, { zone: 'utc' }).toISO({
      suppressMilliseconds: false,
    }) as string;
  }
}
