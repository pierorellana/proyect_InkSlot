import { CalendarCrypto } from './calendar.crypto';

describe('CalendarCrypto', () => {
  const key = Buffer.alloc(32, 7);

  it('round-trips a refresh token without returning plaintext payload', () => {
    const crypto = new CalendarCrypto(key);
    const encrypted = crypto.encrypt('refresh-token-secret');

    expect(encrypted).toMatch(/^v1:[^:]+:[^:]+:[^:]+$/);
    expect(encrypted).not.toContain('refresh-token-secret');
    expect(crypto.decrypt(encrypted)).toBe('refresh-token-secret');
  });

  it('uses a different IV for two encryptions of the same token', () => {
    const crypto = new CalendarCrypto(key);
    const first = crypto.encrypt('refresh-token-secret');
    const second = crypto.encrypt('refresh-token-secret');

    expect(first).not.toBe(second);
    expect(first.split(':')[1]).not.toBe(second.split(':')[1]);
  });

  it('rejects a tampered authentication tag', () => {
    const crypto = new CalendarCrypto(key);
    const encrypted = crypto.encrypt('refresh-token-secret');
    const parts = encrypted.split(':');
    parts[2] = `${parts[2].startsWith('a') ? 'b' : 'a'}${parts[2].slice(1)}`;

    expect(() => crypto.decrypt(parts.join(':'))).toThrow(
      'Invalid encrypted calendar token',
    );
  });

  it('rejects keys that are not exactly 32 bytes', () => {
    expect(() => new CalendarCrypto(Buffer.alloc(31))).toThrow(
      'Calendar encryption key must be exactly 32 bytes',
    );
  });
});
