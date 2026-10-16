import {
  ConflictException,
  HttpException,
  ServiceUnavailableException,
  ValidationPipe,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { createHash } from 'node:crypto';

import { PublicConfirmDto } from './public-confirmation.dto';
import { PublicConfirmationService } from './public-confirmation.service';
import type { PublicConfirmationResponse } from './public-confirmation.types';

describe('PublicConfirmationService', () => {
  const token = 'opaque-token-for-confirmation';
  const requestId = '22222222-2222-4222-8222-222222222222';
  const artistId = '11111111-1111-4111-8111-111111111111';
  const startAt = new Date('2026-10-20T15:00:00.000Z');
  const context = {
    requestId,
    artistId,
    status: 'pending' as const,
    durationMinutes: 60,
    timezone: 'America/Guayaquil',
    expiresAt: new Date('2026-10-21T00:00:00.000Z'),
    minDate: '2026-10-20',
    maxDate: '2026-10-20',
    allowedWeekdays: [2],
    allowedWindows: [{ startLocal: '10:00', endLocal: '12:00' }],
  };
  const slot = {
    startAt,
    endAt: new Date('2026-10-20T16:00:00.000Z'),
    timezone: context.timezone,
    refreshed: { timezone: context.timezone, days: [] },
  };
  const response: PublicConfirmationResponse = {
    status: 'confirmed',
    syncStatus: 'pending',
    startAt: startAt.toISOString(),
    endAt: slot.endAt.toISOString(),
    timezone: context.timezone,
  };

  const tx = {
    $queryRaw: jest.fn().mockResolvedValue([]),
    bookingRequest: {
      findUnique: jest.fn().mockResolvedValue({
        id: requestId,
        artistId,
        status: 'PENDING',
        version: 1,
      }),
      update: jest.fn().mockResolvedValue({}),
    },
    bookingToken: {
      findUnique: jest.fn().mockResolvedValue({
        id: '33333333-3333-4333-8333-333333333333',
        requestId,
        expiresAt: new Date('2026-10-21T00:00:00.000Z'),
        revokedAt: null,
        consumedAt: null,
      }),
      update: jest.fn().mockResolvedValue({}),
    },
    appointment: {
      create: jest.fn().mockResolvedValue({
        id: '44444444-4444-4444-8444-444444444444',
      }),
    },
    outboxEvent: { create: jest.fn().mockResolvedValue({}) },
    idempotencyKey: {
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({}),
      delete: jest.fn().mockResolvedValue({}),
    },
  };
  const prisma = {
    idempotencyKey: { findUnique: jest.fn() },
    appointment: { findUnique: jest.fn() },
    $transaction: jest.fn(),
  };
  const availability = { assertSlotAvailable: jest.fn() };
  const requests = {
    resolvePublicAvailabilityContext: jest.fn(),
    resolvePublicAppointmentContext: jest.fn(),
  };
  let service: PublicConfirmationService;

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-10-15T12:00:00.000Z'));
    jest.resetAllMocks();
    availability.assertSlotAvailable.mockResolvedValue(slot);
    requests.resolvePublicAvailabilityContext.mockResolvedValue(context);
    prisma.idempotencyKey.findUnique.mockResolvedValue(null);
    prisma.$transaction.mockImplementation(
      (operation: (value: typeof tx) => Promise<unknown>) => operation(tx),
    );
    tx.$queryRaw.mockResolvedValue([]);
    tx.bookingRequest.findUnique.mockResolvedValue({
      id: requestId,
      artistId,
      status: 'PENDING',
      version: 1,
    });
    tx.bookingToken.findUnique.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      requestId,
      expiresAt: new Date('2026-10-21T00:00:00.000Z'),
      revokedAt: null,
      consumedAt: null,
    });
    tx.appointment.create.mockResolvedValue({
      id: '44444444-4444-4444-8444-444444444444',
    });
    tx.idempotencyKey.findUnique.mockResolvedValue(null);
    service = new PublicConfirmationService(
      prisma as unknown as PrismaService,
      availability as unknown as PublicAvailabilityService,
      requests as unknown as BookingRequestsService,
    );
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  async function expectCode(
    operation: Promise<unknown>,
    code: string,
    status: number,
  ): Promise<void> {
    const error: unknown = await operation.catch((failure: unknown) => failure);
    expect(error).toBeInstanceOf(HttpException);
    if (!(error instanceof HttpException))
      throw new Error('Expected HTTP error');
    expect(error.getStatus()).toBe(status);
    expect(error.getResponse()).toEqual(
      expect.objectContaining({
        error: expect.objectContaining({ code }),
      }),
    );
  }

  it('confirms the slot atomically and stores only safe replay data', async () => {
    await expect(
      service.confirm(token, 'confirmation-key', {
        startAt: startAt.toISOString(),
      }),
    ).resolves.toEqual(response);

    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), {
      isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      maxWait: 5_000,
      timeout: 10_000,
    });
    expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
    expect(tx.appointment.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        requestId,
        artistId,
        startAt,
        endAt: slot.endAt,
        status: 'CONFIRMED',
        syncStatus: 'PENDING',
      }),
    });
    expect(tx.bookingRequest.update).toHaveBeenCalledWith({
      where: { id: requestId },
      data: { status: 'BOOKED', version: { increment: 1 } },
    });
    expect(tx.outboxEvent.create).toHaveBeenCalledWith({
      data: {
        aggregateId: '44444444-4444-4444-8444-444444444444',
        type: 'appointment.calendar.create',
        payload: {
          appointmentId: '44444444-4444-4444-8444-444444444444',
          operation: 'create',
        },
      },
    });
    const idempotency = tx.idempotencyKey.create.mock.calls[0]?.[0];
    expect(idempotency?.data.responseCode).toBe(201);
    expect(idempotency?.data.expiresAt).toEqual(
      new Date('2026-10-16T12:00:00.000Z'),
    );
    expect(JSON.stringify(idempotency?.data)).not.toContain(token);
  });

  it('replays an active key before validating the token again', async () => {
    const requestHash = createHash('sha256')
      .update(JSON.stringify({ startAt: startAt.toISOString() }))
      .digest('hex');
    prisma.idempotencyKey.findUnique.mockResolvedValue({
      id: '55555555-5555-4555-8555-555555555555',
      keyHash: 'a'.repeat(64),
      scope: 'public-confirmation:v1:token-hash',
      requestHash,
      responseCode: 201,
      responseBody: response,
      createdAt: new Date('2026-10-15T11:00:00.000Z'),
      expiresAt: new Date('2026-10-16T12:00:00.000Z'),
    });

    await expect(
      service.confirm(token, 'confirmation-key', {
        startAt: startAt.toISOString(),
      }),
    ).resolves.toEqual(response);
    expect(requests.resolvePublicAvailabilityContext).not.toHaveBeenCalled();
    expect(availability.assertSlotAvailable).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects reuse with a different normalized payload', async () => {
    prisma.idempotencyKey.findUnique.mockResolvedValue({
      id: '55555555-5555-4555-8555-555555555555',
      keyHash: 'a'.repeat(64),
      scope: 'public-confirmation:v1:token-hash',
      requestHash: 'b'.repeat(64),
      responseCode: 201,
      responseBody: response,
      createdAt: new Date('2026-10-15T11:00:00.000Z'),
      expiresAt: new Date('2026-10-16T12:00:00.000Z'),
    });

    await expectCode(
      service.confirm(token, 'confirmation-key', {
        startAt: startAt.toISOString(),
      }),
      'IDEMPOTENCY_REUSED',
      409,
    );
    expect(requests.resolvePublicAvailabilityContext).not.toHaveBeenCalled();
  });

  it('does not write when preflight fails', async () => {
    availability.assertSlotAvailable.mockRejectedValue(
      new ServiceUnavailableException(safeCalendarError()),
    );

    await expectCode(
      service.confirm(token, 'confirmation-key', {
        startAt: startAt.toISOString(),
      }),
      'CALENDAR_UNAVAILABLE',
      503,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(tx.appointment.create).not.toHaveBeenCalled();
  });

  it('validates strict UTC body and idempotency key', async () => {
    await expectCode(
      service.confirm(token, undefined, { startAt: startAt.toISOString() }),
      'BAD_REQUEST',
      400,
    );
    await expectCode(
      service.confirm(token, 'key', { startAt: '2026-10-20T10:00:00Z' }),
      'BAD_REQUEST',
      400,
    );
  });

  it('returns a safe appointment lookup without internal identifiers', async () => {
    requests.resolvePublicAppointmentContext.mockResolvedValue({
      requestId,
      artistId,
      timezone: context.timezone,
    });
    prisma.appointment.findUnique.mockResolvedValue({
      status: 'CONFIRMED',
      syncStatus: 'PENDING',
      startAt,
      endAt: slot.endAt,
    });

    await expect(service.getAppointment(token)).resolves.toEqual(response);
    expect(prisma.appointment.findUnique).toHaveBeenCalledWith({
      where: { requestId },
      select: { status: true, syncStatus: true, startAt: true, endAt: true },
    });
    expect(JSON.stringify(response)).not.toContain(requestId);
    expect(JSON.stringify(response)).not.toContain(artistId);
  });

  it('retries bounded serializable failures and sanitizes exhausted failures', async () => {
    const serialization = new Prisma.PrismaClientKnownRequestError('private', {
      code: 'P2034',
      clientVersion: '6.19.0',
    });
    prisma.$transaction
      .mockRejectedValueOnce(serialization)
      .mockRejectedValueOnce(serialization)
      .mockRejectedValueOnce(serialization);

    await expectCode(
      service.confirm(token, 'confirmation-key', {
        startAt: startAt.toISOString(),
      }),
      'SERVICE_UNAVAILABLE',
      503,
    );
    expect(prisma.$transaction).toHaveBeenCalledTimes(3);
  });

  it('validates unknown body fields through the application pipe', async () => {
    const pipe = new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    });
    await expect(
      pipe.transform(
        { startAt: startAt.toISOString(), unexpected: true },
        { type: 'body', metatype: PublicConfirmDto },
      ),
    ).rejects.toBeInstanceOf(HttpException);
  });
});

function safeCalendarError(): { error: { code: string; message: string } } {
  return {
    error: {
      code: 'CALENDAR_UNAVAILABLE',
      message: 'No fue posible verificar la disponibilidad del calendario',
    },
  };
}

type PrismaService = import('../database/prisma.service').PrismaService;
type PublicAvailabilityService =
  import('../availability/public-availability.service').PublicAvailabilityService;
type BookingRequestsService =
  import('../requests/requests.service').BookingRequestsService;
