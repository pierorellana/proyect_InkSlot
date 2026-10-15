import { readCalendarConfig } from './calendar.config';

describe('CalendarConfig', () => {
  it('is unconfigured when Google values are absent', () => {
    expect(readCalendarConfig({}).configured).toBe(false);
  });

  it('parses scopes and validates a 32-byte AES key', () => {
    const config = readCalendarConfig({
      GOOGLE_CLIENT_ID: 'client-id',
      GOOGLE_CLIENT_SECRET: 'client-secret',
      GOOGLE_REDIRECT_URI: 'http://localhost:3000/v1/admin/calendar/callback',
      GOOGLE_CALENDAR_NAME: 'InkSlot',
      GOOGLE_CALENDAR_SCOPES: 'scope-a, scope-b',
      GOOGLE_TOKEN_ENCRYPTION_KEY: Buffer.alloc(32).toString('base64'),
    });

    expect(config.configured).toBe(true);
    expect(config.calendarName).toBe('InkSlot');
    expect(config.scopes).toEqual(['scope-a', 'scope-b']);
    expect(config.tokenEncryptionKey).toHaveLength(32);
  });

  it('accepts a 32-byte hexadecimal key', () => {
    const config = readCalendarConfig({
      GOOGLE_CLIENT_ID: 'client-id',
      GOOGLE_CLIENT_SECRET: 'client-secret',
      GOOGLE_REDIRECT_URI: 'http://localhost:3000/v1/admin/calendar/callback',
      GOOGLE_TOKEN_ENCRYPTION_KEY: 'a'.repeat(64),
    });

    expect(config.tokenEncryptionKey).toHaveLength(32);
  });

  it('rejects a malformed encryption key', () => {
    expect(() =>
      readCalendarConfig({
        GOOGLE_TOKEN_ENCRYPTION_KEY: 'too-short',
      }),
    ).toThrow('GOOGLE_TOKEN_ENCRYPTION_KEY');
  });
});
