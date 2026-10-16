import {
  BadRequestException,
  INestApplication,
  ServiceUnavailableException,
  ValidationPipe,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import {
  AppointmentStatus,
  BookingRequestStatus,
  Prisma,
  SyncStatus,
} from '@prisma/client';
import { DateTime } from 'luxon';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import { CalendarService } from '../src/calendar/calendar.service';
import { PrismaService } from '../src/database/prisma.service';
import { hashBookingToken } from '../src/requests/booking-token';

type Fixture = {
  artistId: string;
  requestId: string;
  token: string;
  tokenHash: string;
  clientName: string;
};

type ErrorResponse = {
  status: number;
  body: { error?: { code?: string; message?: string } };
};

describe('public booking confirmation', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  const fixtures: Fixture[] = [];
  const timezone = 'America/Guayaquil';
  const date = '2026-10-20';
  const startAt = '2026-10-20T15:00:00.000Z';
  const alternateStartAt = '2026-10-20T15:30:00.000Z';
  let busy: Array<{ startAt: Date; endAt: Date }> = [];
  let calendarUnavailable = false;
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
      return busy;
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
        exceptionFactory: () =>
          new BadRequestException({
            error: {
              code: 'BAD_REQUEST',
              message: 'Los datos enviados no son válidos',
            },
          }),
      }),
    );
    await app.init();
    prisma = app.get(PrismaService);
  });

  beforeEach(() => {
    busy = [];
    calendarUnavailable = false;
    calendar.queryBusy.mockClear();
  });

  afterEach(async () => {
    while (fixtures.length > 0) {
      const fixture = fixtures.pop();
      if (fixture) await cleanupFixture(fixture);
    }
  });

  afterAll(async () => {
    await app.close();
  });

  async function createFixture(): Promise<Fixture> {
    const suffix = `${Date.now()}-${Math.random()}`;
    const clientName = `Confirmation private client ${suffix}`;
    const artist = await prisma.artist.create({
      data: {
        email: `confirmation-${suffix}@example.test`,
        passwordHash: 'test-password-hash',
        displayName: 'Confirmation Test Artist',
      },
    });
    await prisma.studioSettings.create({
      data: {
        artistId: artist.id,
        timezone,
        slotStepMinutes: 30,
        bufferMinutes: 0,
        minimumNoticeHours: 0,
        horizonDays: 90,
      },
    });
    await prisma.weeklyAvailability.create({
      data: {
        artistId: artist.id,
        weekday: 2,
        startLocal: clockToTime('10:00'),
        endLocal: clockToTime('12:00'),
      },
    });
    const client = await prisma.client.create({
      data: { artistId: artist.id, name: clientName },
    });
    const bookingRequest = await prisma.bookingRequest.create({
      data: {
        artistId: artist.id,
        clientId: client.id,
        durationMinutes: 60,
        minDate: new Date(`${date}T00:00:00.000Z`),
        maxDate: new Date(`${date}T00:00:00.000Z`),
        allowedWeekdays: [2] as Prisma.InputJsonValue,
        allowedWindows: [
          { startLocal: '10:00', endLocal: '12:00' },
        ] as Prisma.InputJsonValue,
      },
    });
    const token = `confirmation-token-${suffix}`;
    const tokenHash = hashBookingToken(token);
    await prisma.bookingToken.create({
      data: {
        requestId: bookingRequest.id,
        tokenHash,
        expiresAt: new Date('2026-10-22T00:00:00.000Z'),
      },
    });
    const fixture = {
      artistId: artist.id,
      requestId: bookingRequest.id,
      token,
      tokenHash,
      clientName,
    };
    fixtures.push(fixture);
    return fixture;
  }

  async function cleanupFixture(fixture: Fixture): Promise<void> {
    const appointments = await prisma.appointment.findMany({
      where: { artistId: fixture.artistId },
      select: { id: true },
    });
    const appointmentIds = appointments.map((appointment) => appointment.id);
    if (appointmentIds.length > 0) {
      await prisma.outboxEvent.deleteMany({
        where: { aggregateId: { in: appointmentIds } },
      });
    }
    await prisma.idempotencyKey.deleteMany({
      where: { scope: `public-confirmation:v1:${fixture.tokenHash}` },
    });
    await prisma.appointment.deleteMany({
      where: { artistId: fixture.artistId },
    });
    await prisma.bookingToken.deleteMany({
      where: { requestId: fixture.requestId },
    });
    await prisma.bookingRequest.deleteMany({
      where: { id: fixture.requestId },
    });
    await prisma.client.deleteMany({ where: { artistId: fixture.artistId } });
    await prisma.weeklyAvailability.deleteMany({
      where: { artistId: fixture.artistId },
    });
    await prisma.studioSettings.deleteMany({
      where: { artistId: fixture.artistId },
    });
    await prisma.artist.delete({ where: { id: fixture.artistId } });
  }

  function clockToTime(clock: string): Date {
    const [hour, minute] = clock.split(':').map(Number);
    return new Date(Date.UTC(1970, 0, 1, hour, minute));
  }

  function localInstant(clock: string): Date {
    return DateTime.fromISO(`${date}T${clock}`, { zone: timezone })
      .toUTC()
      .toJSDate();
  }

  function errorCode(response: ErrorResponse): string | undefined {
    return response.body.error?.code;
  }

  async function expectNoWrites(fixture: Fixture): Promise<void> {
    const requestRow = await prisma.bookingRequest.findUniqueOrThrow({
      where: { id: fixture.requestId },
    });
    const tokenRow = await prisma.bookingToken.findUniqueOrThrow({
      where: { tokenHash: fixture.tokenHash },
    });
    expect(requestRow.status).toBe(BookingRequestStatus.PENDING);
    expect(tokenRow.consumedAt).toBeNull();
    expect(
      await prisma.appointment.count({
        where: { requestId: fixture.requestId },
      }),
    ).toBe(0);
    expect(
      await prisma.idempotencyKey.count({
        where: { scope: `public-confirmation:v1:${fixture.tokenHash}` },
      }),
    ).toBe(0);
    expect(
      await prisma.outboxEvent.count({
        where: { aggregateId: fixture.requestId },
      }),
    ).toBe(0);
  }

  it('confirms once, persists the outbox, consumes the token, and supports safe lookup', async () => {
    const fixture = await createFixture();
    const confirmed = await request(app.getHttpServer())
      .post(`/v1/public/reservations/${fixture.token}/confirm`)
      .set('Idempotency-Key', 'confirmation-key')
      .send({ startAt })
      .expect(201);

    expect(confirmed.body).toEqual({
      status: 'confirmed',
      syncStatus: 'pending',
      startAt,
      endAt: '2026-10-20T16:00:00.000Z',
      timezone,
    });
    expect(Object.keys(confirmed.body).sort()).toEqual([
      'endAt',
      'startAt',
      'status',
      'syncStatus',
      'timezone',
    ]);

    const requestRow = await prisma.bookingRequest.findUniqueOrThrow({
      where: { id: fixture.requestId },
    });
    const tokenRow = await prisma.bookingToken.findUniqueOrThrow({
      where: { tokenHash: fixture.tokenHash },
    });
    const appointment = await prisma.appointment.findUniqueOrThrow({
      where: { requestId: fixture.requestId },
    });
    const outbox = await prisma.outboxEvent.findFirstOrThrow({
      where: { aggregateId: appointment.id },
    });
    expect(requestRow.status).toBe(BookingRequestStatus.BOOKED);
    expect(tokenRow.consumedAt).not.toBeNull();
    expect(appointment.status).toBe(AppointmentStatus.CONFIRMED);
    expect(appointment.syncStatus).toBe(SyncStatus.PENDING);
    expect(outbox).toMatchObject({
      type: 'appointment.calendar.create',
      status: 'PENDING',
      payload: { appointmentId: appointment.id, operation: 'create' },
    });

    const lookup = await request(app.getHttpServer())
      .get(`/v1/public/reservations/${fixture.token}/appointment`)
      .expect(200);
    expect(lookup.body).toEqual(confirmed.body);
    for (const privateValue of [
      fixture.token,
      'confirmation-key',
      fixture.clientName,
      fixture.requestId,
      fixture.artistId,
      fixture.tokenHash,
    ]) {
      expect(JSON.stringify(confirmed.body)).not.toContain(privateValue);
      expect(JSON.stringify(lookup.body)).not.toContain(privateValue);
    }
  });

  it('replays the same key and rejects a different payload without another write', async () => {
    const fixture = await createFixture();
    const path = `/v1/public/reservations/${fixture.token}/confirm`;
    const first = await request(app.getHttpServer())
      .post(path)
      .set('Idempotency-Key', 'replay-key')
      .send({ startAt })
      .expect(201);
    const callsAfterFirst = calendar.queryBusy.mock.calls.length;
    const replay = await request(app.getHttpServer())
      .post(path)
      .set('Idempotency-Key', 'replay-key')
      .send({ startAt })
      .expect(201);
    expect(replay.body).toEqual(first.body);
    expect(calendar.queryBusy).toHaveBeenCalledTimes(callsAfterFirst);

    const reused = (await request(app.getHttpServer())
      .post(path)
      .set('Idempotency-Key', 'replay-key')
      .send({ startAt: alternateStartAt })) as unknown as ErrorResponse;
    expect(reused.status).toBe(409);
    expect(errorCode(reused)).toBe('IDEMPOTENCY_REUSED');
  });

  it('allows exactly one winner for concurrent different keys on the same request', async () => {
    const fixture = await createFixture();
    const path = `/v1/public/reservations/${fixture.token}/confirm`;
    const [first, second] = await Promise.all([
      request(app.getHttpServer())
        .post(path)
        .set('Idempotency-Key', 'race-a')
        .send({ startAt }),
      request(app.getHttpServer())
        .post(path)
        .set('Idempotency-Key', 'race-b')
        .send({ startAt }),
    ]);

    expect([first.status, second.status].sort()).toEqual([201, 409]);
    const requestRow = await prisma.bookingRequest.findUniqueOrThrow({
      where: { id: fixture.requestId },
    });
    expect(requestRow.status).toBe(BookingRequestStatus.BOOKED);
    expect(
      await prisma.appointment.count({
        where: { requestId: fixture.requestId },
      }),
    ).toBe(1);
    expect(
      await prisma.bookingToken.count({
        where: { requestId: fixture.requestId, consumedAt: { not: null } },
      }),
    ).toBe(1);
    const appointment = await prisma.appointment.findUniqueOrThrow({
      where: { requestId: fixture.requestId },
    });
    expect(
      await prisma.outboxEvent.count({
        where: { aggregateId: appointment.id },
      }),
    ).toBe(1);
  });

  it('leaves PostgreSQL unchanged when the slot is busy or Calendar is unavailable', async () => {
    const busyFixture = await createFixture();
    busy = [{ startAt: localInstant('10:00'), endAt: localInstant('11:00') }];
    const busyResponse = (await request(app.getHttpServer())
      .post(`/v1/public/reservations/${busyFixture.token}/confirm`)
      .set('Idempotency-Key', 'busy-key')
      .send({ startAt })) as unknown as ErrorResponse;
    expect(busyResponse.status).toBe(409);
    expect(errorCode(busyResponse)).toBe('SLOT_UNAVAILABLE');
    await expectNoWrites(busyFixture);

    const unavailableFixture = await createFixture();
    busy = [];
    calendarUnavailable = true;
    const unavailable = (await request(app.getHttpServer())
      .post(`/v1/public/reservations/${unavailableFixture.token}/confirm`)
      .set('Idempotency-Key', 'calendar-key')
      .send({ startAt })) as unknown as ErrorResponse;
    expect(unavailable.status).toBe(503);
    expect(errorCode(unavailable)).toBe('CALENDAR_UNAVAILABLE');
    await expectNoWrites(unavailableFixture);
  });

  it('rejects malformed request data and lifecycle states safely', async () => {
    const fixture = await createFixture();
    const missingKey = (await request(app.getHttpServer())
      .post(`/v1/public/reservations/${fixture.token}/confirm`)
      .send({ startAt })) as unknown as ErrorResponse;
    expect(missingKey.status).toBe(400);
    expect(errorCode(missingKey)).toBe('BAD_REQUEST');

    const malformed = (await request(app.getHttpServer())
      .post(`/v1/public/reservations/${fixture.token}/confirm`)
      .set('Idempotency-Key', 'valid-key')
      .send({ startAt: '2026-10-20T15:00:00Z' })) as unknown as ErrorResponse;
    expect(malformed.status).toBe(400);
    expect(errorCode(malformed)).toBe('BAD_REQUEST');

    const unknownField = (await request(app.getHttpServer())
      .post(`/v1/public/reservations/${fixture.token}/confirm`)
      .set('Idempotency-Key', 'valid-key-2')
      .send({ startAt, extra: true })) as unknown as ErrorResponse;
    expect(unknownField.status).toBe(400);
    expect(errorCode(unknownField)).toBe('BAD_REQUEST');

    const expired = await createFixture();
    await prisma.bookingToken.update({
      where: { tokenHash: expired.tokenHash },
      data: { expiresAt: new Date('2000-01-01T00:00:00.000Z') },
    });
    const expiredResponse = (await request(app.getHttpServer())
      .post(`/v1/public/reservations/${expired.token}/confirm`)
      .set('Idempotency-Key', 'expired-key')
      .send({ startAt })) as unknown as ErrorResponse;
    expect(expiredResponse.status).toBe(410);
    expect(errorCode(expiredResponse)).toBe('TOKEN_EXPIRED');

    const revoked = await createFixture();
    await prisma.bookingToken.update({
      where: { tokenHash: revoked.tokenHash },
      data: { revokedAt: new Date() },
    });
    const revokedResponse = (await request(app.getHttpServer())
      .post(`/v1/public/reservations/${revoked.token}/confirm`)
      .set('Idempotency-Key', 'revoked-key')
      .send({ startAt })) as unknown as ErrorResponse;
    expect(revokedResponse.status).toBe(410);
    expect(errorCode(revokedResponse)).toBe('TOKEN_REVOKED');

    const unknown = (await request(app.getHttpServer())
      .post('/v1/public/reservations/not-a-real-token/confirm')
      .set('Idempotency-Key', 'unknown-key')
      .send({ startAt })) as unknown as ErrorResponse;
    expect(unknown.status).toBe(404);
    expect(errorCode(unknown)).toBe('TOKEN_NOT_FOUND');
  });
});
