import { ConflictException, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../database/prisma.service';
import { CalendarService } from '../calendar/calendar.service';
import { AvailabilityEngine } from './availability.engine';
import {
  AppointmentAvailabilityService,
  type AppointmentAvailabilityInput,
  type AppointmentAvailabilityRequest,
} from './appointment-availability.service';

describe('AppointmentAvailabilityService', () => {
  const artistId = '11111111-1111-4111-8111-111111111111';
  const appointmentId = '22222222-2222-4222-8222-222222222222';
  const startAt = new Date('2026-10-20T15:00:00.000Z');
  const timeMin = new Date('2026-10-20T05:00:00.000Z');
  const timeMax = new Date('2026-10-21T05:00:00.000Z');
  const defaultRequest = {
    minDate: null,
    maxDate: null,
    allowedWeekdays: null,
    allowedWindows: null,
  } as AppointmentAvailabilityRequest;
  const request = { ...defaultRequest };
  const defaultSettings = {
    timezone: 'America/Guayaquil',
    slotStepMinutes: 30,
    bufferMinutes: 15,
    minimumNoticeHours: 0,
    horizonDays: 90,
  };
  const settings = { ...defaultSettings };
  const weeklyRows = [
    {
      weekday: 2,
      startLocal: new Date('1970-01-01T10:00:00.000Z'),
      endLocal: new Date('1970-01-01T18:00:00.000Z'),
    },
  ];

  const prisma = {
    studioSettings: { findUnique: jest.fn() },
    weeklyAvailability: { findMany: jest.fn() },
    availabilityBlock: { findMany: jest.fn() },
    appointment: { findMany: jest.fn() },
  };
  const calendar = { queryBusy: jest.fn() };
  let service: AppointmentAvailabilityService;

  const input = (
    overrides: Partial<AppointmentAvailabilityInput> = {},
  ): AppointmentAvailabilityInput => ({
    artistId,
    appointmentId,
    startAt,
    durationMinutes: 60,
    request,
    ...overrides,
  });

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-10-15T12:00:00.000Z'));
    jest.resetAllMocks();
    Object.assign(request, defaultRequest);
    Object.assign(settings, defaultSettings);
    prisma.studioSettings.findUnique.mockResolvedValue(settings);
    prisma.weeklyAvailability.findMany.mockResolvedValue(weeklyRows);
    prisma.availabilityBlock.findMany.mockResolvedValue([]);
    prisma.appointment.findMany.mockResolvedValue([]);
    calendar.queryBusy.mockResolvedValue([]);
    service = new AppointmentAvailabilityService(
      prisma as unknown as PrismaService,
      calendar as unknown as CalendarService,
      new AvailabilityEngine(),
    );
  });

  afterEach(() => jest.useRealTimers());

  function expectSlotUnavailable(error: unknown): void {
    expect(error).toBeInstanceOf(ConflictException);
    expect((error as ConflictException).getStatus()).toBe(409);
    expect((error as ConflictException).getResponse()).toEqual({
      error: {
        code: 'SLOT_UNAVAILABLE',
        message: 'El horario seleccionado ya no está disponible',
      },
    });
  }

  it('returns the exact candidate and calculates its end from the duration', async () => {
    await expect(service.assertAvailable(input())).resolves.toEqual({
      startAt,
      endAt: new Date('2026-10-20T16:00:00.000Z'),
      timezone: settings.timezone,
    });

    expect(prisma.appointment.findMany).toHaveBeenCalledWith({
      where: {
        artistId,
        id: { not: appointmentId },
        startAt: { lt: timeMax },
        endAt: { gt: timeMin },
        status: { in: ['CONFIRMED', 'COMPLETED', 'NO_SHOW'] },
      },
      select: { startAt: true, endAt: true },
    });
    expect(calendar.queryBusy).toHaveBeenCalledWith(artistId, {
      timeMin,
      timeMax,
      timeZone: settings.timezone,
    });
  });

  it('excludes the current appointment from internal conflicts', async () => {
    prisma.appointment.findMany.mockResolvedValue([
      {
        startAt: new Date('2026-10-20T15:00:00.000Z'),
        endAt: new Date('2026-10-20T16:00:00.000Z'),
      },
    ]);

    await expect(service.assertAvailable(input())).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(prisma.appointment.findMany.mock.calls[0]?.[0].where.id).toEqual({
      not: appointmentId,
    });
  });

  it('rejects an overlapping internal appointment', async () => {
    prisma.appointment.findMany.mockResolvedValue([
      {
        startAt: new Date('2026-10-20T15:30:00.000Z'),
        endAt: new Date('2026-10-20T16:30:00.000Z'),
      },
    ]);

    const error = await service
      .assertAvailable(input())
      .catch((failure: unknown) => failure);

    expectSlotUnavailable(error);
  });

  it('rejects a busy external interval, including the current event interval', async () => {
    calendar.queryBusy.mockResolvedValue([
      {
        startAt,
        endAt: new Date('2026-10-20T16:00:00.000Z'),
      },
    ]);

    const error = await service
      .assertAvailable(input())
      .catch((failure: unknown) => failure);

    expectSlotUnavailable(error);
  });

  it.each([
    [
      'outside the weekly working window',
      () => {
        prisma.weeklyAvailability.findMany.mockResolvedValue([
          {
            weekday: 1,
            startLocal: new Date('1970-01-01T10:00:00.000Z'),
            endLocal: new Date('1970-01-01T18:00:00.000Z'),
          },
        ]);
      },
    ],
    [
      'outside request weekdays',
      () => {
        Object.assign(request, { allowedWeekdays: [1] });
      },
    ],
    [
      'outside request windows',
      () => {
        Object.assign(request, {
          allowedWindows: [{ startLocal: '11:00', endLocal: '12:00' }],
        });
      },
    ],
    [
      'inside a blocked interval',
      () => {
        prisma.availabilityBlock.findMany.mockResolvedValue([
          {
            startAt: new Date('2026-10-20T14:00:00.000Z'),
            endAt: new Date('2026-10-20T16:00:00.000Z'),
          },
        ]);
      },
    ],
    [
      'before the minimum notice',
      () => {
        Object.assign(settings, { minimumNoticeHours: 24 });
        prisma.weeklyAvailability.findMany.mockResolvedValue([
          {
            weekday: 4,
            startLocal: new Date('1970-01-01T10:00:00.000Z'),
            endLocal: new Date('1970-01-01T18:00:00.000Z'),
          },
        ]);
      },
    ],
    [
      'after the scheduling horizon',
      () => {
        Object.assign(settings, { horizonDays: 1 });
      },
    ],
    [
      'outside request date restrictions',
      () => {
        Object.assign(request, {
          minDate: new Date('2026-10-21T00:00:00.000Z'),
        });
      },
    ],
  ])('rejects a candidate %s', async (_reason, arrange) => {
    arrange();

    const error = await service
      .assertAvailable(input())
      .catch((failure: unknown) => failure);

    expectSlotUnavailable(error);
  });

  it('propagates the safe Calendar unavailable response before accepting the slot', async () => {
    const errorResponse = {
      error: {
        code: 'CALENDAR_UNAVAILABLE',
        message: 'No fue posible verificar la disponibilidad del calendario',
      },
    };
    calendar.queryBusy.mockRejectedValue(
      new ServiceUnavailableException(errorResponse),
    );

    await expect(service.assertAvailable(input())).rejects.toMatchObject({
      response: errorResponse,
      status: 503,
    });
  });

  it('fails closed when the stored timezone is invalid', async () => {
    prisma.studioSettings.findUnique.mockResolvedValue({
      ...settings,
      timezone: 'Not/An-Iana-Zone',
    });

    await expect(service.assertAvailable(input())).rejects.toMatchObject({
      response: {
        error: {
          code: 'AVAILABILITY_NOT_CONFIGURED',
        },
      },
      status: 503,
    });
    expect(calendar.queryBusy).not.toHaveBeenCalled();
  });
});
