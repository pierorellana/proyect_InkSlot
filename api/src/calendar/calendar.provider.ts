export type CalendarSummary = {
  id: string;
  name: string;
};

export type CalendarTokens = {
  refreshToken: string;
};

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

export type CalendarProviderErrorCode =
  | 'CALENDAR_NOT_CONFIGURED'
  | 'CALENDAR_UNAVAILABLE'
  | 'CALENDAR_REAUTH_REQUIRED'
  | 'CALENDAR_EVENT_EXISTS'
  | 'CALENDAR_EVENT_NOT_FOUND'
  | 'OAUTH_ACCESS_DENIED';

export class CalendarProviderError extends Error {
  constructor(
    public readonly code: CalendarProviderErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'CalendarProviderError';
  }
}

export interface CalendarProvider {
  authorizationUrl(input: { state: string }): string;
  exchangeCode(code: string): Promise<CalendarTokens>;
  listCalendars(refreshToken: string): Promise<CalendarSummary[]>;
  freeBusy(input: CalendarBusyQuery): Promise<CalendarBusyInterval[]>;
  createEvent(input: CalendarEventInput): Promise<CalendarEventResult>;
  updateEvent(input: CalendarEventInput): Promise<CalendarEventResult>;
  deleteEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<void>;
  getEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<CalendarEventResult | null>;
  revoke(refreshToken: string): Promise<void>;
}
