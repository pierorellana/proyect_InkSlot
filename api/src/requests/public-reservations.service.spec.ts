import { HttpException } from '@nestjs/common';
import { BookingRequestStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import { hashBookingToken } from './booking-token';
import { BookingRequestsService } from './requests.service';

type PublicTokenRecord = Prisma.BookingTokenGetPayload<{
  include: {
    request: {
      include: {
        artist: {
          select: {
            displayName: true;
            studioSettings: { select: { timezone: true } };
          };
        };
      };
    };
  };
}>;

describe('BookingRequestsService public resolution', () => {
  const artistId = '11111111-1111-4111-8111-111111111111';
  const requestId = '22222222-2222-4222-8222-222222222222';
  const tokenId = '33333333-3333-4333-8333-333333333333';
  const rawToken = 'public-unit-test-token';
  const tokenHash = hashBookingToken(rawToken);
  const now = new Date('2026-10-15T12:00:00.000Z');

  const bookingToken = {
    findUnique: jest.fn<
      Promise<PublicTokenRecord | null>,
      [Prisma.BookingTokenFindUniqueArgs]
    >(),
    findFirst: jest.fn<
      Promise<{ id: string } | null>,
      [Prisma.BookingTokenFindFirstArgs]
    >(),
  };
  const bookingRequest = {
    updateMany: jest.fn<
      Promise<Prisma.BatchPayload>,
      [Prisma.BookingRequestUpdateManyArgs]
    >(),
  };
  const transaction = { bookingToken, bookingRequest };
  const prisma = {
    bookingToken,
    bookingRequest,
    $transaction: jest.fn<
      Promise<unknown>,
      [
        (
          operation: (tx: Prisma.TransactionClient) => Promise<unknown>,
        ) => Promise<unknown>,
        object,
      ]
    >(),
  };
  let service: BookingRequestsService;

  const record = (): PublicTokenRecord => ({
    id: tokenId,
    requestId,
    tokenHash,
    expiresAt: new Date('2026-10-17T12:00:00.000Z'),
    revokedAt: null,
    consumedAt: null,
    createdAt: now,
    request: {
      id: requestId,
      artistId,
      clientId: '44444444-4444-4444-8444-444444444444',
      depositVerifiedAt: now,
      depositVerifiedBy: artistId,
      durationMinutes: 180,
      status: BookingRequestStatus.PENDING,
      minDate: new Date('2026-10-20T00:00:00.000Z'),
      maxDate: new Date('2026-11-30T00:00:00.000Z'),
      allowedWeekdays: [2, 3, 4, 5, 6],
      allowedWindows: [{ startLocal: '10:00', endLocal: '20:00' }],
      createdAt: now,
      version: 1,
      artist: {
        displayName: 'InkSlot Artist',
        studioSettings: { timezone: 'America/Guayaquil' },
      },
    },
  });

  beforeEach(() => {
    jest.resetAllMocks();
    jest.useFakeTimers().setSystemTime(now);
    bookingToken.findUnique.mockResolvedValue(record());
    bookingToken.findFirst.mockResolvedValue(null);
    bookingRequest.updateMany.mockResolvedValue({ count: 1 });
    prisma.$transaction.mockImplementation((operation) =>
      operation(transaction as unknown as Prisma.TransactionClient),
    );
    service = new BookingRequestsService(prisma as unknown as PrismaService);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  async function expectCode(
    operation: Promise<unknown>,
    code: string,
    status: number,
  ) {
    const error: unknown = await operation.catch((failure: unknown) => failure);
    expect(error).toBeInstanceOf(HttpException);
    if (!(error instanceof HttpException))
      throw new Error('Expected safe HTTP error');
    expect(error.getStatus()).toBe(status);
    const response = error.getResponse();
    if (
      typeof response !== 'object' ||
      response === null ||
      !('error' in response)
    ) {
      throw new Error('Expected safe error envelope');
    }
    const envelope = response as {
      error: { code?: unknown; message?: unknown };
    };
    expect(envelope.error.code).toBe(code);
    expect(typeof envelope.error.message).toBe('string');
    expect(JSON.stringify(response)).not.toContain(rawToken);
    expect(JSON.stringify(response)).not.toContain(tokenHash);
  }

  it('looks up by SHA-256 hash and returns only the approved pending summary', async () => {
    const result = await service.resolvePublic(rawToken);

    const lookup = bookingToken.findUnique.mock.calls[0]?.[0];
    expect(lookup?.where).toEqual({ tokenHash });
    expect(lookup?.include).toBeDefined();
    expect(result).toEqual({
      status: 'pending',
      artist: { displayName: 'InkSlot Artist' },
      durationMinutes: 180,
      timezone: 'America/Guayaquil',
      restrictions: {
        minDate: '2026-10-20',
        maxDate: '2026-11-30',
        allowedWeekdays: [2, 3, 4, 5, 6],
        allowedWindows: [{ startLocal: '10:00', endLocal: '20:00' }],
      },
      expiresAt: '2026-10-17T12:00:00.000Z',
    });

    const serialized = JSON.stringify(result);
    for (const privateValue of [
      'clientId',
      'client@example.com',
      'Cliente Privado',
      '+593000000000',
      artistId,
      requestId,
      tokenId,
      tokenHash,
      rawToken,
      'depositVerifiedAt',
      'notes',
    ]) {
      expect(serialized).not.toContain(privateValue);
    }
  });

  it('returns a safe booked status', async () => {
    const booked = record();
    booked.request.status = BookingRequestStatus.BOOKED;
    bookingToken.findUnique.mockResolvedValue(booked);

    await expect(service.resolvePublic(rawToken)).resolves.toMatchObject({
      status: 'booked',
      artist: { displayName: 'InkSlot Artist' },
    });
  });

  it('keeps a booked result readable after token consumption and expiry', async () => {
    const booked = record();
    booked.request.status = BookingRequestStatus.BOOKED;
    booked.consumedAt = now;
    booked.expiresAt = new Date('2026-10-14T12:00:00.000Z');
    bookingToken.findUnique.mockResolvedValue(booked);

    await expect(service.resolvePublic(rawToken)).resolves.toMatchObject({
      status: 'booked',
      expiresAt: '2026-10-14T12:00:00.000Z',
    });
  });

  it('returns TOKEN_NOT_FOUND for an unknown hash', async () => {
    bookingToken.findUnique.mockResolvedValue(null);

    await expectCode(service.resolvePublic(rawToken), 'TOKEN_NOT_FOUND', 404);
  });

  it('expires a pending request safely when no replacement token is active', async () => {
    const expired = record();
    expired.expiresAt = new Date('2026-10-15T11:59:59.000Z');
    bookingToken.findUnique.mockResolvedValue(expired);

    await expectCode(service.resolvePublic(rawToken), 'TOKEN_EXPIRED', 410);
    expect(bookingToken.findFirst).toHaveBeenCalledWith({
      where: {
        requestId,
        revokedAt: null,
        consumedAt: null,
        expiresAt: { gt: now },
      },
      select: { id: true },
    });
    expect(bookingRequest.updateMany).toHaveBeenCalledWith({
      where: { id: requestId, status: BookingRequestStatus.PENDING },
      data: { status: BookingRequestStatus.EXPIRED, version: { increment: 1 } },
    });
  });

  it('does not expire the request when a newer active replacement exists', async () => {
    const expired = record();
    expired.expiresAt = new Date('2026-10-15T11:59:59.000Z');
    bookingToken.findUnique.mockResolvedValue(expired);
    bookingToken.findFirst.mockResolvedValue({
      id: '55555555-5555-4555-8555-555555555555',
    });

    await expectCode(service.resolvePublic(rawToken), 'TOKEN_EXPIRED', 410);
    expect(bookingRequest.updateMany).not.toHaveBeenCalled();
  });

  it.each([
    [
      'revoked token',
      (value: PublicTokenRecord) => {
        value.revokedAt = now;
      },
      'TOKEN_REVOKED',
    ],
    [
      'consumed token',
      (value: PublicTokenRecord) => {
        value.consumedAt = now;
      },
      'TOKEN_REVOKED',
    ],
    [
      'cancelled request',
      (value: PublicTokenRecord) => {
        value.request.status = BookingRequestStatus.CANCELLED;
      },
      'TOKEN_REVOKED',
    ],
    [
      'closed request',
      (value: PublicTokenRecord) => {
        value.request.status = BookingRequestStatus.CLOSED;
      },
      'TOKEN_REVOKED',
    ],
    [
      'expired request',
      (value: PublicTokenRecord) => {
        value.request.status = BookingRequestStatus.EXPIRED;
      },
      'TOKEN_EXPIRED',
    ],
  ])('rejects %s with the safe public error', async (_label, mutate, code) => {
    const value = record();
    mutate(value);
    bookingToken.findUnique.mockResolvedValue(value);

    await expectCode(service.resolvePublic(rawToken), code, 410);
  });

  it('requires studio settings for an active token', async () => {
    const value = record();
    value.request.artist.studioSettings = null;
    bookingToken.findUnique.mockResolvedValue(value);

    await expectCode(
      service.resolvePublic(rawToken),
      'SERVICE_UNAVAILABLE',
      503,
    );
  });

  it('sanitizes lookup and expiration persistence failures', async () => {
    bookingToken.findUnique.mockRejectedValue(new Error(`private ${rawToken}`));
    await expectCode(
      service.resolvePublic(rawToken),
      'SERVICE_UNAVAILABLE',
      503,
    );

    const expired = record();
    expired.expiresAt = new Date('2026-10-15T11:59:59.000Z');
    bookingToken.findUnique.mockResolvedValue(expired);
    prisma.$transaction.mockRejectedValue(new Error(`private ${tokenHash}`));
    await expectCode(
      service.resolvePublic(rawToken),
      'SERVICE_UNAVAILABLE',
      503,
    );
  });
});
