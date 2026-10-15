import { BadRequestException } from '@nestjs/common';

import {
  decodeBookingCursor,
  encodeBookingCursor,
  generateBookingToken,
  hashBookingToken,
} from './booking-token';

const id = 'bcbead40-5a3e-437d-97f8-4474a6228029';
const createdAt = new Date('2026-10-15T22:00:00.000Z');
const encodeJson = (value: unknown): string =>
  Buffer.from(JSON.stringify(value), 'utf8').toString('base64url');

describe('booking tokens', () => {
  it('generates a URL-safe token containing 32 random bytes and its hash', () => {
    const generated = generateBookingToken();

    expect(generated.token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(Buffer.from(generated.token, 'base64url')).toHaveLength(32);
    expect(generated.tokenHash).toBe(hashBookingToken(generated.token));
    expect(generated.tokenHash).not.toContain(generated.token);
  });

  it('generates distinct tokens and hashes on repeated calls', () => {
    const generated = Array.from({ length: 100 }, () => generateBookingToken());

    expect(new Set(generated.map(({ token }) => token)).size).toBe(100);
    expect(new Set(generated.map(({ tokenHash }) => tokenHash)).size).toBe(100);
  });

  it('hashes UTF-8 input deterministically using SHA-256 hex', () => {
    expect(hashBookingToken('abc')).toBe(
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(hashBookingToken('enlace-público')).toBe(
      hashBookingToken('enlace-público'),
    );
    expect(hashBookingToken('enlace-público')).toMatch(/^[a-f0-9]{64}$/);
    expect(hashBookingToken('abc')).not.toBe(hashBookingToken('ABC'));
  });
});

describe('booking cursors', () => {
  it('round-trips a timestamp and UUID as base64url JSON', () => {
    const cursor = encodeBookingCursor({ createdAt, id });

    expect(cursor).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(decodeBookingCursor(cursor)).toEqual({ createdAt, id });
    expect(
      JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')),
    ).toEqual({
      createdAt: createdAt.toISOString(),
      id,
    });
  });

  it('encodes only the timestamp and ID, excluding raw tokens and other fields', () => {
    const { token } = generateBookingToken();
    const input = { createdAt, id, token, notes: 'private' };
    const cursor = encodeBookingCursor(input);
    const payload = Buffer.from(cursor, 'base64url').toString('utf8');

    expect(cursor).not.toContain(token);
    expect(payload).not.toContain(token);
    expect(Object.keys(JSON.parse(payload) as object).sort()).toEqual([
      'createdAt',
      'id',
    ]);
  });

  it.each([
    ['empty', ''],
    ['invalid alphabet', '%%%'],
    ['padding', `${encodeJson({ createdAt, id })}=`],
    ['whitespace', ` ${encodeJson({ createdAt, id })}`],
    ['standard base64 alphabet', '+/8'],
    ['non-canonical trailing bits', 'Zh'],
    ['oversized input', 'a'.repeat(257)],
    ['non-JSON', Buffer.from('private-token').toString('base64url')],
    ['null', encodeJson(null)],
    ['array', encodeJson([createdAt, id])],
    ['string', encodeJson('private-token')],
    ['number', encodeJson(42)],
    ['missing timestamp', encodeJson({ id })],
    ['missing ID', encodeJson({ createdAt })],
    ['extra field', encodeJson({ createdAt, id, token: 'private-token' })],
    ['prototype field', encodeJson({ createdAt, id, constructor: 'private' })],
    ['invalid UUID', encodeJson({ createdAt, id: 'private-token' })],
    [
      'invalid UUID version',
      encodeJson({ createdAt, id: id.replace('437d', '037d') }),
    ],
    [
      'invalid UUID variant',
      encodeJson({ createdAt, id: id.replace('97f8', '77f8') }),
    ],
    ['numeric ID', encodeJson({ createdAt, id: 42 })],
    ['null ID', encodeJson({ createdAt, id: null })],
    ['invalid date', encodeJson({ createdAt: 'invalid', id })],
    [
      'normalized invalid date',
      encodeJson({ createdAt: '2026-02-30T00:00:00.000Z', id }),
    ],
    [
      'date without timezone',
      encodeJson({ createdAt: '2026-10-15T22:00:00.000', id }),
    ],
    ['numeric date', encodeJson({ createdAt: 0, id })],
    ['null date', encodeJson({ createdAt: null, id })],
  ])('rejects %s with a safe error', (_label, cursor) => {
    let error: unknown;
    try {
      decodeBookingCursor(cursor);
    } catch (caught) {
      error = caught;
    }

    expect(error).toBeInstanceOf(BadRequestException);
    const exception = error as BadRequestException;
    expect(exception.getStatus()).toBe(400);
    expect(exception.getResponse()).toEqual({
      error: { code: 'BAD_REQUEST', message: 'El cursor no es válido' },
    });
    expect(JSON.stringify(exception.getResponse())).not.toContain(
      'private-token',
    );
  });
});
