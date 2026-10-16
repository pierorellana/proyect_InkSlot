import { BadRequestException } from '@nestjs/common';

export type AppointmentCursor = {
  startAt: Date;
  id: string;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_CURSOR_LENGTH = 256;

const invalidCursor = (): BadRequestException =>
  new BadRequestException({
    error: { code: 'BAD_REQUEST', message: 'El cursor no es válido' },
  });

export function encodeAppointmentCursor(input: AppointmentCursor): string {
  return Buffer.from(
    JSON.stringify({ startAt: input.startAt.toISOString(), id: input.id }),
    'utf8',
  ).toString('base64url');
}

export function decodeAppointmentCursor(cursor: string): AppointmentCursor {
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
    typeof value.startAt !== 'string'
  ) {
    throw invalidCursor();
  }

  const startAt = new Date(value.startAt);
  if (
    !Number.isFinite(startAt.getTime()) ||
    startAt.toISOString() !== value.startAt
  ) {
    throw invalidCursor();
  }

  return { startAt, id: value.id };
}
