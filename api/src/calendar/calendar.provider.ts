export type CalendarSummary = {
  id: string;
  name: string;
};

export type CalendarTokens = {
  refreshToken: string;
};

export type CalendarProviderErrorCode =
  'CALENDAR_NOT_CONFIGURED' | 'CALENDAR_UNAVAILABLE' | 'OAUTH_ACCESS_DENIED';

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
  revoke(refreshToken: string): Promise<void>;
}
