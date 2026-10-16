import {
  INestApplication,
  ServiceUnavailableException,
  ValidationPipe,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AppointmentStatus, Prisma } from '@prisma/client';
import { DateTime } from 'luxon';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { CalendarService } from '../src/calendar/calendar.service';
import { PrismaService } from '../src/database/prisma.service';
import { hashBookingToken } from '../src/requests/booking-token';

type AvailabilityResponse = {
  timezone: string;
  days: Array<{
    date: string;
    slots: Array<{ startAt: string; endAt: string }>;
  }>;
};

type HttpErrorResponse = {
  status: number;
  body: { error?: { code?: string; message?: string } };
};

type TokenFixture = {
  artistId: string;
  requestId: string;
  token: string;
};

describe('public availability', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let artistId: string;
  let otherArtistId: string;
  let targetDate: string;
  let targetWeekday: number;
  let calendarUnavailable = false;

  const timezone = 'America/Guayaquil';
  const calendar = {
    queryBusy: jest.fn().mockImplementation(async () => {
      if (calendarUnavailable) {
        throw new ServiceUnavailableException({
          error: {
            code: 'CALENDAR_UNAVAILABLE',
            message:
              'No fue posible verificar la disponibilidad del calendario',
          },
        });
      }
      return [];
    }),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(CalendarService)
      .useValue(calendar)
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1');
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();

    prisma = app.get(PrismaService);
    const date = DateTime.now()
      .setZone(timezone)
      .plus({ days: 10 })
      .startOf('day');
    targetDate = date.toISODate() as string;
    targetWeekday = date.weekday % 7;

    const [artist, otherArtist] = await Promise.all([
      createArtist('primary'),
      createArtist('other'),
    ]);
    artistId = artist.id;
    otherArtistId = otherArtist.id;

    await Promise.all([
      createSettings(artistId, '10:00', '12:00'),
      createSettings(otherArtistId, '14:00', '16:00'),
    ]);
  });

  afterAll(async () => {
    if (prisma) {
      if (artistId) await cleanupArtist(artistId);
      if (otherArtistId) await cleanupArtist(otherArtistId);
    }
    if (app) await app.close();
  });

  beforeEach(() => {
    calendarUnavailable = false;
    calendar.queryBusy.mockClear();
  });

  async function createArtist(label: string) {
    return prisma.artist.create({
      data: {
        email: `public-availability-${label}-${Date.now()}-${Math.random()}@example.test`,
        passwordHash: 'test-password-hash',
        displayName: `Public ${label}`,
      },
    });
  }

  async function createSettings(
    id: string,
    startLocal: string,
    endLocal: string,
  ) {
    await prisma.studioSettings.create({
      data: {
        artistId: id,
        timezone,
        slotStepMinutes: 30,
        bufferMinutes: 0,
        minimumNoticeHours: 0,
        horizonDays: 90,
      },
    });
    await prisma.weeklyAvailability.create({
      data: {
        artistId: id,
        weekday: targetWeekday,
        startLocal: clockToTime(startLocal),
        endLocal: clockToTime(endLocal),
      },
    });
  }

  async function createToken(
    id: string,
    options: {
      minDate?: string;
      maxDate?: string;
      allowedWeekdays?: number[];
      allowedWindows?: Array<{ startLocal: string; endLocal: string }>;
    } = {},
  ): Promise<TokenFixture> {
    const client = await prisma.client.create({
      data: {
        artistId: id,
        name: `Public client ${Date.now()}-${Math.random()}`,
      },
    });
    const bookingRequest = await prisma.bookingRequest.create({
      data: {
        artistId: id,
        clientId: client.id,
        durationMinutes: 60,
        minDate: options.minDate
          ? new Date(`${options.minDate}T00:00:00.000Z`)
          : null,
        maxDate: options.maxDate
          ? new Date(`${options.maxDate}T00:00:00.000Z`)
          : null,
        allowedWeekdays: options.allowedWeekdays as Prisma.InputJsonValue,
        allowedWindows: options.allowedWindows as Prisma.InputJsonValue,
      },
    });
    const token = `public-availability-${Date.now()}-${Math.random()}`;
    await prisma.bookingToken.create({
      data: {
        requestId: bookingRequest.id,
        tokenHash: hashBookingToken(token),
        expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      },
    });
    return { artistId: id, requestId: bookingRequest.id, token };
  }

  async function createAppointment(id: string, startAt: Date, endAt: Date) {
    const fixture = await createToken(id);
    await prisma.appointment.create({
      data: {
        requestId: fixture.requestId,
        artistId: id,
        startAt,
        endAt,
        status: AppointmentStatus.CONFIRMED,
      },
    });
    return fixture;
  }

  async function cleanupArtist(id: string): Promise<void> {
    const requests = await prisma.bookingRequest.findMany({
      where: { artistId: id },
      select: { id: true },
    });
    const requestIds = requests.map((requestRow) => requestRow.id);
    await prisma.appointment.deleteMany({ where: { artistId: id } });
    await prisma.bookingToken.deleteMany({
      where: { request: { artistId: id } },
    });
    await prisma.auditLog.deleteMany({
      where: {
        OR: [
          { actorId: id },
          ...(requestIds.length > 0 ? [{ entityId: { in: requestIds } }] : []),
        ],
      },
    });
    await prisma.bookingRequest.deleteMany({ where: { artistId: id } });
    await prisma.client.deleteMany({ where: { artistId: id } });
    await prisma.availabilityBlock.deleteMany({ where: { artistId: id } });
    await prisma.weeklyAvailability.deleteMany({ where: { artistId: id } });
    await prisma.studioSettings.deleteMany({ where: { artistId: id } });
    await prisma.artist.delete({ where: { id } });
  }

  function clockToTime(clock: string): Date {
    const [hour, minute] = clock.split(':').map(Number);
    return new Date(Date.UTC(1970, 0, 1, hour, minute));
  }

  function localInstant(date: string, clock: string): Date {
    return DateTime.fromISO(`${date}T${clock}`, { zone: timezone })
      .toUTC()
      .toJSDate();
  }

  function errorCode(response: HttpErrorResponse): string | undefined {
    return response.body.error?.code;
  }

  function slots(response: AvailabilityResponse) {
    return response.days.flatMap((day) => day.slots);
  }

  it('returns only server-calculated active slots in UTC', async () => {
    const fixture = await createToken(artistId, {
      minDate: targetDate,
      maxDate: targetDate,
      allowedWeekdays: [targetWeekday],
    });

    const response = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${fixture.token}/availability`)
      .query({ from: targetDate, to: targetDate })
      .expect(200);
    const body = response.body as AvailabilityResponse;

    expect(body.timezone).toBe(timezone);
    expect(body.days).toHaveLength(1);
    expect(body.days[0]?.date).toBe(targetDate);
    expect(slots(body)).toEqual([
      {
        startAt: localInstant(targetDate, '10:00').toISOString(),
        endAt: localInstant(targetDate, '11:00').toISOString(),
      },
      {
        startAt: localInstant(targetDate, '10:30').toISOString(),
        endAt: localInstant(targetDate, '11:30').toISOString(),
      },
      {
        startAt: localInstant(targetDate, '11:00').toISOString(),
        endAt: localInstant(targetDate, '12:00').toISOString(),
      },
    ]);
    expect(Object.keys(body)).toEqual(['timezone', 'days']);
    expect(Object.keys(body.days[0] ?? {})).toEqual(['date', 'slots']);
    expect(calendar.queryBusy).toHaveBeenCalledWith(
      artistId,
      expect.objectContaining({ timeZone: timezone }),
    );
  });

  it('returns no days when the request restrictions or schedule have no match', async () => {
    const restricted = await createToken(artistId, {
      minDate: targetDate,
      maxDate: targetDate,
      allowedWeekdays: [(targetWeekday + 1) % 7],
      allowedWindows: [{ startLocal: '14:00', endLocal: '15:00' }],
    });

    const response = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${restricted.token}/availability`)
      .query({ from: targetDate, to: targetDate })
      .expect(200);

    expect(response.body).toEqual({ timezone, days: [] });
  });

  it('excludes intersecting internal blocks and appointments', async () => {
    const block = await prisma.availabilityBlock.create({
      data: {
        artistId,
        startAt: localInstant(targetDate, '10:30'),
        endAt: localInstant(targetDate, '11:00'),
      },
    });
    await createAppointment(
      artistId,
      localInstant(targetDate, '11:00'),
      localInstant(targetDate, '12:00'),
    );
    const fixture = await createToken(artistId, {
      minDate: targetDate,
      maxDate: targetDate,
    });

    const response = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${fixture.token}/availability`)
      .query({ from: targetDate, to: targetDate })
      .expect(200);

    expect(response.body).toEqual({ timezone, days: [] });
    await prisma.availabilityBlock.delete({ where: { id: block.id } });
  });

  it('keeps public availability isolated by artist', async () => {
    const fixture = await createToken(otherArtistId, {
      minDate: targetDate,
      maxDate: targetDate,
    });

    const response = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${fixture.token}/availability`)
      .query({ from: targetDate, to: targetDate })
      .expect(200);
    const body = response.body as AvailabilityResponse;

    expect(slots(body)).toEqual([
      {
        startAt: localInstant(targetDate, '14:00').toISOString(),
        endAt: localInstant(targetDate, '15:00').toISOString(),
      },
      {
        startAt: localInstant(targetDate, '14:30').toISOString(),
        endAt: localInstant(targetDate, '15:30').toISOString(),
      },
      {
        startAt: localInstant(targetDate, '15:00').toISOString(),
        endAt: localInstant(targetDate, '16:00').toISOString(),
      },
    ]);
    expect(calendar.queryBusy).toHaveBeenCalledWith(
      otherArtistId,
      expect.any(Object),
    );
  });

  it('rejects invalid date-only ranges with the public bad-request envelope', async () => {
    const invalid = (await request(app.getHttpServer())
      .get('/v1/public/reservations/not-used/availability')
      .query({
        from: '2026-02-30',
        to: '2026-03-01',
      })) as unknown as HttpErrorResponse;
    expect(invalid.status).toBe(400);
    expect(errorCode(invalid)).toBe('BAD_REQUEST');

    const reversed = (await request(app.getHttpServer())
      .get('/v1/public/reservations/not-used/availability')
      .query({
        from: '2026-03-02',
        to: '2026-03-01',
      })) as unknown as HttpErrorResponse;
    expect(reversed.status).toBe(400);
    expect(errorCode(reversed)).toBe('BAD_REQUEST');

    const tooLong = (await request(app.getHttpServer())
      .get('/v1/public/reservations/not-used/availability')
      .query({
        from: '2026-03-01',
        to: '2026-04-01',
      })) as unknown as HttpErrorResponse;
    expect(tooLong.status).toBe(400);
    expect(errorCode(tooLong)).toBe('BAD_REQUEST');
  });

  it('returns the safe lifecycle errors for unknown, expired, revoked, and booked tokens', async () => {
    const unknown = (await request(app.getHttpServer()).get(
      '/v1/public/reservations/not-a-real-token/availability?from=2026-03-01&to=2026-03-01',
    )) as unknown as HttpErrorResponse;
    expect(unknown.status).toBe(404);
    expect(errorCode(unknown)).toBe('TOKEN_NOT_FOUND');

    const expired = await createToken(artistId);
    await prisma.bookingToken.updateMany({
      where: { requestId: expired.requestId },
      data: { expiresAt: new Date('2000-01-01T00:00:00.000Z') },
    });
    const expiredResponse = (await request(app.getHttpServer())
      .get(`/v1/public/reservations/${expired.token}/availability`)
      .query({
        from: targetDate,
        to: targetDate,
      })) as unknown as HttpErrorResponse;
    expect(expiredResponse.status).toBe(410);
    expect(errorCode(expiredResponse)).toBe('TOKEN_EXPIRED');

    const revoked = await createToken(artistId);
    await prisma.bookingToken.updateMany({
      where: { requestId: revoked.requestId },
      data: { revokedAt: new Date() },
    });
    const revokedResponse = (await request(app.getHttpServer())
      .get(`/v1/public/reservations/${revoked.token}/availability`)
      .query({
        from: targetDate,
        to: targetDate,
      })) as unknown as HttpErrorResponse;
    expect(revokedResponse.status).toBe(410);
    expect(errorCode(revokedResponse)).toBe('TOKEN_REVOKED');

    const booked = await createToken(artistId);
    await prisma.bookingRequest.update({
      where: { id: booked.requestId },
      data: { status: 'BOOKED' },
    });
    const bookedResponse = (await request(app.getHttpServer())
      .get(`/v1/public/reservations/${booked.token}/availability`)
      .query({
        from: targetDate,
        to: targetDate,
      })) as unknown as HttpErrorResponse;
    expect(bookedResponse.status).toBe(409);
    expect(errorCode(bookedResponse)).toBe('ALREADY_BOOKED');
  });

  it('propagates Calendar unavailability without returning slots', async () => {
    calendarUnavailable = true;
    const fixture = await createToken(artistId, {
      minDate: targetDate,
      maxDate: targetDate,
    });

    const response = (await request(app.getHttpServer())
      .get(`/v1/public/reservations/${fixture.token}/availability`)
      .query({
        from: targetDate,
        to: targetDate,
      })) as unknown as HttpErrorResponse;
    expect(response.status).toBe(503);
    expect(errorCode(response)).toBe('CALENDAR_UNAVAILABLE');
  });
});
