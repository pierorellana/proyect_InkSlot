import { BadRequestException } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';

export type GeneratedBookingToken = {
  token: string;
  tokenHash: string;
};

type BookingCursor = {
  createdAt: Date;
  id: string;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_CURSOR_LENGTH = 256;

const invalidCursor = (): BadRequestException =>
  new BadRequestException({
    error: { code: 'BAD_REQUEST', message: 'El cursor no es válido' },
  });

export function generateBookingToken(): GeneratedBookingToken {
  const token = randomBytes(32).toString('base64url');
  return { token, tokenHash: hashBookingToken(token) };
}

export function hashBookingToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

export function encodeBookingCursor(input: BookingCursor): string {
  return Buffer.from(
    JSON.stringify({ createdAt: input.createdAt.toISOString(), id: input.id }),
    'utf8',
  ).toString('base64url');
}

export function decodeBookingCursor(cursor: string): BookingCursor {
  if (
    typeof cursor !== 'string' ||
    cursor.length > MAX_CURSOR_LENGTH ||
    !/^[A-Za-z0-9_-]+$/.test(cursor)
  ) {
    throw invalidCursor();
  }

  const buffer = Buffer.from(cursor, 'base64url');
  if (buffer.toString('base64url') !== cursor) {
    throw invalidCursor();
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(buffer.toString('utf8'));
  } catch {
    throw invalidCursor();
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw invalidCursor();
  }

  const value = parsed as Record<string, unknown>;
  if (
    Object.keys(value).length !== 2 ||
    typeof value.id !== 'string' ||
    !UUID_PATTERN.test(value.id) ||
    typeof value.createdAt !== 'string'
  ) {
    throw invalidCursor();
  }

  const createdAt = new Date(value.createdAt);
  if (
    !Number.isFinite(createdAt.getTime()) ||
    createdAt.toISOString() !== value.createdAt
  ) {
    throw invalidCursor();
  }

  return { createdAt, id: value.id };
}
