import { ConflictException, ServiceUnavailableException } from '@nestjs/common';
import { AvailabilityEngine } from './availability.engine';
import { PublicAvailabilityService } from './public-availability.service';

describe('PublicAvailabilityService exact slot preflight', () => {
  const context = {
    requestId: '22222222-2222-4222-8222-222222222222',
    artistId: '11111111-1111-4111-8111-111111111111',
    status: 'pending' as const,
    durationMinutes: 60,
    timezone: 'America/Guayaquil',
    expiresAt: new Date('2026-10-20T00:00:00.000Z'),
    minDate: '2026-10-20',
    maxDate: '2026-10-20',
    allowedWeekdays: [2],
    allowedWindows: [{ startLocal: '10:00', endLocal: '12:00' }],
  };
  const token = 'opaque-public-token';
  const startAt = new Date('2026-10-20T15:00:00.000Z');
  const requestResolver = {
    resolvePublicAvailabilityContext: jest.fn().mockResolvedValue(context),
  };
  const calendar = { queryBusy: jest.fn().mockResolvedValue([]) };
  const prisma = {
    studioSettings: { findUnique: jest.fn() },
    weeklyAvailability: { findMany: jest.fn() },
    availabilityBlock: { findMany: jest.fn() },
    appointment: { findMany: jest.fn() },
  };
  let service: PublicAvailabilityService;

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-10-15T12:00:00.000Z'));
    jest.resetAllMocks();
    requestResolver.resolvePublicAvailabilityContext.mockResolvedValue(context);
    calendar.queryBusy.mockResolvedValue([]);
    prisma.studioSettings.findUnique.mockResolvedValue({
      timezone: context.timezone,
      slotStepMinutes: 30,
      bufferMinutes: 0,
      minimumNoticeHours: 0,
      horizonDays: 90,
    });
    prisma.weeklyAvailability.findMany.mockResolvedValue([
      {
        weekday: 2,
        startLocal: new Date('1970-01-01T10:00:00.000Z'),
        endLocal: new Date('1970-01-01T12:00:00.000Z'),
      },
    ]);
    prisma.availabilityBlock.findMany.mockResolvedValue([]);
    prisma.appointment.findMany.mockResolvedValue([]);
    service = new PublicAvailabilityService(
      prisma as unknown as PrismaService,
      requestResolver as unknown as BookingRequestsService,
      calendar as unknown as CalendarService,
      new AvailabilityEngine(),
    );
  });

  afterEach(() => jest.useRealTimers());

  it('accepts an exact slot returned by the public engine', async () => {
    await expect(service.assertSlotAvailable(token, startAt)).resolves.toEqual(
      expect.objectContaining({
        startAt,
        endAt: new Date('2026-10-20T16:00:00.000Z'),
        timezone: context.timezone,
      }),
    );
    expect(calendar.queryBusy).toHaveBeenCalledWith(
      context.artistId,
      expect.objectContaining({
        timeMin: new Date('2026-10-20T05:00:00.000Z'),
        timeMax: new Date('2026-10-21T05:00:00.000Z'),
        timeZone: context.timezone,
      }),
    );
  });

  it('returns a safe conflict with refreshed availability when the slot is absent', async () => {
    const error = await service
      .assertSlotAvailable(token, new Date('2026-10-20T16:30:00.000Z'))
      .catch((failure: unknown) => failure);

    expect(error).toBeInstanceOf(ConflictException);
    expect((error as ConflictException).getStatus()).toBe(409);
    expect((error as ConflictException).getResponse()).toEqual(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'SLOT_UNAVAILABLE' }),
        availability: expect.objectContaining({ timezone: context.timezone }),
      }),
    );
  });

  it('rejects an internal appointment conflict before confirmation writes', async () => {
    prisma.appointment.findMany.mockResolvedValue([
      {
        startAt: new Date('2026-10-20T14:30:00.000Z'),
        endAt: new Date('2026-10-20T15:30:00.000Z'),
      },
    ]);

    const error = await service
      .assertSlotAvailable(token, startAt)
      .catch((failure: unknown) => failure);

    expect((error as ConflictException).getStatus()).toBe(409);
    expect(
      JSON.stringify((error as ConflictException).getResponse()),
    ).not.toContain(context.requestId);
  });

  it('preserves the safe Calendar unavailable error', async () => {
    calendar.queryBusy.mockRejectedValue(
      new ServiceUnavailableException({
        error: {
          code: 'CALENDAR_UNAVAILABLE',
          message: 'No fue posible verificar la disponibilidad del calendario',
        },
      }),
    );

    await expect(
      service.assertSlotAvailable(token, startAt),
    ).rejects.toMatchObject(
      expect.objectContaining({
        response: expect.objectContaining({
          error: expect.objectContaining({ code: 'CALENDAR_UNAVAILABLE' }),
        }),
      }),
    );
  });
});

type PrismaService = import('../database/prisma.service').PrismaService;
type BookingRequestsService =
  import('../requests/requests.service').BookingRequestsService;
type CalendarService = import('../calendar/calendar.service').CalendarService;
