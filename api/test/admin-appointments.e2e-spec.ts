import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import {
  AppointmentStatus,
  CalendarConnectionStatus,
  OutboxStatus,
  Prisma,
  SyncStatus,
} from '@prisma/client';
import * as argon2 from 'argon2';
import request from 'supertest';

import { AppModule } from '../src/app.module';
import {
  CALENDAR_CONFIG,
  CALENDAR_PROVIDER,
} from '../src/calendar/calendar.constants';
import type { CalendarConfig } from '../src/calendar/calendar.config';
import { CalendarCrypto } from '../src/calendar/calendar.crypto';
import {
  CalendarProviderError,
  type CalendarBusyInterval,
  type CalendarBusyQuery,
  type CalendarEventInput,
  type CalendarEventResult,
  type CalendarProvider,
} from '../src/calendar/calendar.provider';
import { PrismaService } from '../src/database/prisma.service';
import { CalendarSyncService } from '../src/sync/calendar-sync.service';
import {
  OUTBOX_CREATE_EVENT,
  OUTBOX_DELETE_EVENT,
  OUTBOX_UPDATE_EVENT,
  SYNC_CONFIG,
  type SyncConfig,
} from '../src/sync/sync.constants';
import { OutboxWorkerService } from '../src/sync/outbox-worker.service';

jest.setTimeout(30_000);

type CalendarMode = 'success' | 'unavailable' | 'reauth';

class FakeCalendarProvider implements CalendarProvider {
  mode: CalendarMode = 'success';
  readonly externalEvents = new Map<string, CalendarEventResult>();
  readonly freeBusyCalls: CalendarBusyQuery[] = [];
  readonly createCalls: CalendarEventInput[] = [];
  readonly updateCalls: CalendarEventInput[] = [];
  readonly deleteCalls: Array<{ calendarId: string; eventId: string }> = [];

  authorizationUrl(input: { state: string }): string {
    return `https://calendar.test/?state=${input.state}`;
  }

  async exchangeCode(): Promise<{ refreshToken: string }> {
    return { refreshToken: 'test-refresh-token' };
  }

  async listCalendars(): Promise<Array<{ id: string; name: string }>> {
    return [{ id: 'inkslot-calendar', name: 'InkSlot' }];
  }

  async freeBusy(input: CalendarBusyQuery): Promise<CalendarBusyInterval[]> {
    this.freeBusyCalls.push(input);
    this.throwIfUnavailable();
    return [];
  }

  async createEvent(input: CalendarEventInput): Promise<CalendarEventResult> {
    this.throwIfUnavailable();
    if (this.externalEvents.has(input.eventId)) {
      throw new CalendarProviderError(
        'CALENDAR_EVENT_EXISTS',
        'private provider detail',
      );
    }
    this.createCalls.push(input);
    const result = {
      externalEventId: input.eventId,
      etag: `etag-${input.eventId}`,
    };
    this.externalEvents.set(input.eventId, result);
    return result;
  }

  async updateEvent(input: CalendarEventInput): Promise<CalendarEventResult> {
    this.throwIfUnavailable();
    this.updateCalls.push(input);
    if (!this.externalEvents.has(input.eventId)) {
      throw new CalendarProviderError(
        'CALENDAR_EVENT_NOT_FOUND',
        'private provider detail',
      );
    }
    const result = {
      externalEventId: input.eventId,
      etag: `updated-${input.eventId}`,
    };
    this.externalEvents.set(input.eventId, result);
    return result;
  }

  async deleteEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<void> {
    this.throwIfUnavailable();
    this.deleteCalls.push({
      calendarId: input.calendarId,
      eventId: input.eventId,
    });
    this.externalEvents.delete(input.eventId);
  }

  async getEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<CalendarEventResult | null> {
    this.throwIfUnavailable();
    return this.externalEvents.get(input.eventId) ?? null;
  }

  async revoke(): Promise<void> {}

  reset(): void {
    this.mode = 'success';
    this.externalEvents.clear();
    this.freeBusyCalls.length = 0;
    this.createCalls.length = 0;
    this.updateCalls.length = 0;
    this.deleteCalls.length = 0;
  }

  private throwIfUnavailable(): void {
    if (this.mode === 'reauth') {
      throw new CalendarProviderError(
        'CALENDAR_REAUTH_REQUIRED',
        'private provider detail',
      );
    }
    if (this.mode === 'unavailable') {
      throw new CalendarProviderError(
        'CALENDAR_UNAVAILABLE',
        'private provider detail',
      );
    }
  }
}

type Fixture = {
  artistId: string;
  appointmentId: string;
  requestId: string;
  clientId: string;
  connectionId: string;
  settingsId: string;
  weeklyAvailabilityIds: string[];
  sessionIds: string[];
  password: string;
  email: string;
};

const provider = new FakeCalendarProvider();
const calendarConfig: CalendarConfig = {
  configured: true,
  clientId: 'test-client-id',
  clientSecret: 'test-client-secret',
  redirectUri: 'http://localhost:3000/v1/admin/calendar/callback',
  calendarName: 'InkSlot',
  scopes: ['test-scope'],
  tokenEncryptionKey: Buffer.alloc(32),
};
const crypto = {
  encrypt: jest.fn((value: string) => `encrypted:${value}`),
  decrypt: jest.fn(() => 'test-refresh-token'),
};
const syncConfig: SyncConfig = {
  enabled: false,
  pollIntervalMs: 1_000,
  batchSize: 20,
  leaseMs: 120_000,
  maxAttempts: 5,
  retryBaseMs: 1_000,
  retryMaxMs: 1_000,
  jitterRatio: 0,
};

describe('admin appointments lifecycle', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let worker: OutboxWorkerService;
  const fixtures: Fixture[] = [];

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(CALENDAR_CONFIG)
      .useValue(calendarConfig)
      .overrideProvider(CALENDAR_PROVIDER)
      .useValue(provider)
      .overrideProvider(CalendarCrypto)
      .useValue(crypto)
      .overrideProvider(SYNC_CONFIG)
      .useValue(syncConfig)
      .compile();

    app = moduleRef.createNestApplication({ logger: false });
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
    worker = app.get(OutboxWorkerService);
  });

  beforeEach(() => provider.reset());

  afterEach(async () => {
    while (fixtures.length > 0) {
      const fixture = fixtures.pop();
      if (fixture) await cleanupFixture(fixture);
    }
  });

  afterAll(async () => app.close());

  async function createFixture(label: string): Promise<Fixture> {
    const suffix = `${label}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const password = 'local-test-password';
    const artist = await prisma.artist.create({
      data: {
        email: `admin-appointment-${suffix}@example.test`,
        passwordHash: await argon2.hash(password, { type: argon2.argon2id }),
        displayName: `Appointment Artist ${suffix}`,
      },
    });
    const settings = await prisma.studioSettings.create({
      data: {
        artistId: artist.id,
        timezone: 'America/Guayaquil',
        slotStepMinutes: 30,
        bufferMinutes: 0,
        minimumNoticeHours: 0,
        horizonDays: 90,
      },
    });
    const weekly = await Promise.all(
      [2, 4].map((weekday) =>
        prisma.weeklyAvailability.create({
          data: {
            artistId: artist.id,
            weekday,
            startLocal: new Date('1970-01-01T10:00:00.000Z'),
            endLocal: new Date('1970-01-01T18:00:00.000Z'),
          },
        }),
      ),
    );
    const client = await prisma.client.create({
      data: {
        artistId: artist.id,
        name: `Client ${suffix}`,
        email: `private-${suffix}@example.test`,
        phone: '+593999000000',
      },
    });
    const bookingRequest = await prisma.bookingRequest.create({
      data: {
        artistId: artist.id,
        clientId: client.id,
        paymentReference: `PAYMENT-${suffix}`,
        durationMinutes: 90,
        status: 'BOOKED',
        allowedWeekdays: [2, 4] as Prisma.InputJsonValue,
        allowedWindows: [
          { startLocal: '10:00', endLocal: '18:00' },
        ] as Prisma.InputJsonValue,
      },
    });
    const appointment = await prisma.appointment.create({
      data: {
        requestId: bookingRequest.id,
        artistId: artist.id,
        startAt: new Date('2026-11-03T15:00:00.000Z'),
        endAt: new Date('2026-11-03T16:30:00.000Z'),
        status: AppointmentStatus.CONFIRMED,
        syncStatus: SyncStatus.PENDING,
      },
    });
    const connection = await prisma.calendarConnection.create({
      data: {
        artistId: artist.id,
        calendarId: 'inkslot-calendar',
        calendarName: 'InkSlot',
        encryptedRefreshToken: 'encrypted:test-refresh-token',
        status: CalendarConnectionStatus.CONNECTED,
      },
    });
    await prisma.outboxEvent.create({
      data: {
        aggregateId: appointment.id,
        type: OUTBOX_CREATE_EVENT,
        payload: { appointmentId: appointment.id, operation: 'create' },
      },
    });
    const fixture: Fixture = {
      artistId: artist.id,
      appointmentId: appointment.id,
      requestId: bookingRequest.id,
      clientId: client.id,
      connectionId: connection.id,
      settingsId: settings.id,
      weeklyAvailabilityIds: weekly.map((row) => row.id),
      sessionIds: [],
      password,
      email: artist.email,
    };
    fixtures.push(fixture);
    return fixture;
  }

  async function login(fixture: Fixture): Promise<string[]> {
    const response = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: fixture.email, password: fixture.password })
      .expect(200);
    const sessions = await prisma.adminSession.findMany({
      where: { artistId: fixture.artistId },
      select: { id: true },
    });
    fixture.sessionIds.push(...sessions.map((session) => session.id));
    return response.headers['set-cookie'] as string[];
  }

  async function cleanupFixture(fixture: Fixture): Promise<void> {
    await prisma.auditLog.deleteMany({
      where: { entityType: 'appointment', entityId: fixture.appointmentId },
    });
    await prisma.syncIssue.deleteMany({
      where: { appointmentId: fixture.appointmentId },
    });
    await prisma.calendarEvent.deleteMany({
      where: { appointmentId: fixture.appointmentId },
    });
    await prisma.outboxEvent.deleteMany({
      where: { aggregateId: fixture.appointmentId },
    });
    await prisma.appointment.deleteMany({
      where: { id: fixture.appointmentId },
    });
    await prisma.bookingRequest.deleteMany({
      where: { id: fixture.requestId },
    });
    await prisma.client.deleteMany({ where: { id: fixture.clientId } });
    await prisma.weeklyAvailability.deleteMany({
      where: { id: { in: fixture.weeklyAvailabilityIds } },
    });
    await prisma.calendarConnection.deleteMany({
      where: { id: fixture.connectionId },
    });
    await prisma.studioSettings.deleteMany({
      where: { id: fixture.settingsId },
    });
    await prisma.adminSession.deleteMany({
      where: { id: { in: fixture.sessionIds } },
    });
    await prisma.artist.delete({ where: { id: fixture.artistId } });
  }

  async function getAppointment(fixture: Fixture) {
    return prisma.appointment.findUniqueOrThrow({
      where: { id: fixture.appointmentId },
    });
  }

  it('lists and details only appointments owned by the authenticated artist', async () => {
    const owner = await createFixture('owner');
    const other = await createFixture('other');
    const ownerCookies = await login(owner);
    const otherCookies = await login(other);

    const list = await request(app.getHttpServer())
      .get('/v1/admin/appointments?status=confirmed')
      .set('Cookie', ownerCookies)
      .expect(200);
    expect(list.body.items).toEqual([
      expect.objectContaining({
        id: owner.appointmentId,
        status: 'confirmed',
        durationMinutes: 90,
      }),
    ]);
    expect(JSON.stringify(list.body)).not.toContain('paymentReference');
    expect(JSON.stringify(list.body)).not.toContain('private-owner');

    await request(app.getHttpServer())
      .get(`/v1/admin/appointments/${owner.appointmentId}`)
      .set('Cookie', ownerCookies)
      .expect(200)
      .expect((response) => {
        expect(response.body.client.name).toContain('Client owner');
        expect(response.body.audit).toEqual([]);
      });

    await request(app.getHttpServer())
      .get(`/v1/admin/appointments/${owner.appointmentId}`)
      .set('Cookie', otherCookies)
      .expect(404)
      .expect({ error: { code: 'NOT_FOUND', message: 'La cita no existe' } });
  });

  it('reschedules, audits and updates the same external event id after recreation', async () => {
    const fixture = await createFixture('reschedule');
    const cookies = await login(fixture);
    const workerSync = app.get(CalendarSyncService);

    await worker.drainOnce();
    const eventId = workerSync.deterministicEventId(fixture.appointmentId);
    provider.externalEvents.delete(eventId);

    const response = await request(app.getHttpServer())
      .patch(`/v1/admin/appointments/${fixture.appointmentId}/reschedule`)
      .set('Cookie', cookies)
      .send({ startAt: '2026-11-05T15:00:00.000Z', version: 1 })
      .expect(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        status: 'confirmed',
        startAt: '2026-11-05T15:00:00.000Z',
        endAt: '2026-11-05T16:30:00.000Z',
        version: 2,
      }),
    );
    expect(response.body.audit).toEqual([
      expect.objectContaining({ action: 'rescheduled' }),
    ]);

    const updateOutbox = await prisma.outboxEvent.findFirstOrThrow({
      where: { aggregateId: fixture.appointmentId, type: OUTBOX_UPDATE_EVENT },
    });
    expect(updateOutbox.payload).toEqual({
      appointmentId: fixture.appointmentId,
      operation: 'update',
    });

    await worker.drainOnce();
    expect(provider.updateCalls).toHaveLength(1);
    expect(provider.updateCalls[0].eventId).toBe(eventId);
    expect(provider.createCalls).toHaveLength(2);
    expect(provider.createCalls[1].eventId).toBe(eventId);
    const state = await getAppointment(fixture);
    expect(state.syncStatus).toBe(SyncStatus.SYNCED);
    expect(
      await prisma.auditLog.count({
        where: { entityType: 'appointment', entityId: fixture.appointmentId },
      }),
    ).toBe(1);
  });

  it('cancels immediately and deletes Calendar eventually; repeated cancel is idempotent', async () => {
    const fixture = await createFixture('cancel');
    const cookies = await login(fixture);
    await worker.drainOnce();

    const cancelled = await request(app.getHttpServer())
      .post(`/v1/admin/appointments/${fixture.appointmentId}/cancel`)
      .set('Cookie', cookies)
      .send({ version: 1 })
      .expect(201);
    expect(cancelled.body).toEqual(
      expect.objectContaining({ status: 'cancelled', version: 2 }),
    );
    expect(
      await prisma.outboxEvent.count({
        where: {
          aggregateId: fixture.appointmentId,
          type: OUTBOX_DELETE_EVENT,
        },
      }),
    ).toBe(1);

    await worker.drainOnce();
    expect(provider.deleteCalls).toHaveLength(1);
    expect(
      await prisma.calendarEvent.findUnique({
        where: { appointmentId: fixture.appointmentId },
      }),
    ).toBeNull();

    await request(app.getHttpServer())
      .post(`/v1/admin/appointments/${fixture.appointmentId}/cancel`)
      .set('Cookie', cookies)
      .send({ version: 1 })
      .expect(201)
      .expect((response) => {
        expect(response.body.status).toBe('cancelled');
        expect(response.body.version).toBe(2);
      });
    expect(
      await prisma.outboxEvent.count({
        where: {
          aggregateId: fixture.appointmentId,
          type: OUTBOX_DELETE_EVENT,
        },
      }),
    ).toBe(1);
  });

  it('completes and marks no-show without adding Calendar operations', async () => {
    const completed = await createFixture('completed');
    const completedCookies = await login(completed);
    await request(app.getHttpServer())
      .post(`/v1/admin/appointments/${completed.appointmentId}/complete`)
      .set('Cookie', completedCookies)
      .send({ version: 1 })
      .expect(201)
      .expect((response) => expect(response.body.status).toBe('completed'));

    const completedOperations = await prisma.outboxEvent.findMany({
      where: { aggregateId: completed.appointmentId },
      select: { type: true },
    });
    expect(completedOperations).toEqual([{ type: OUTBOX_CREATE_EVENT }]);

    const noShow = await createFixture('no-show');
    const noShowCookies = await login(noShow);
    await request(app.getHttpServer())
      .post(`/v1/admin/appointments/${noShow.appointmentId}/no-show`)
      .set('Cookie', noShowCookies)
      .send({ version: 1 })
      .expect(201)
      .expect((response) => expect(response.body.status).toBe('no_show'));
  });

  it('rejects stale versions, invalid UTC input and unavailable Calendar safely', async () => {
    const fixture = await createFixture('errors');
    const cookies = await login(fixture);

    await request(app.getHttpServer())
      .patch(`/v1/admin/appointments/${fixture.appointmentId}/reschedule`)
      .set('Cookie', cookies)
      .send({ startAt: '2026-11-05T15:00:00Z', version: 1 })
      .expect(400);

    await prisma.appointment.update({
      where: { id: fixture.appointmentId },
      data: { version: 2 },
    });
    await request(app.getHttpServer())
      .post(`/v1/admin/appointments/${fixture.appointmentId}/cancel`)
      .set('Cookie', cookies)
      .send({ version: 1 })
      .expect(409)
      .expect((response) => {
        expect(response.body.error.code).toBe('APPOINTMENT_VERSION_CONFLICT');
      });

    await prisma.appointment.update({
      where: { id: fixture.appointmentId },
      data: { version: 1 },
    });
    provider.mode = 'unavailable';
    const before = await getAppointment(fixture);
    await request(app.getHttpServer())
      .patch(`/v1/admin/appointments/${fixture.appointmentId}/reschedule`)
      .set('Cookie', cookies)
      .send({ startAt: '2026-11-05T15:00:00.000Z', version: 1 })
      .expect(503)
      .expect((response) => {
        expect(response.body.error.code).toBe('CALENDAR_UNAVAILABLE');
      });
    const after = await getAppointment(fixture);
    expect(after.startAt).toEqual(before.startAt);
    expect(after.version).toBe(before.version);
  });

  it('treats an external delete 404 equivalent as successful cleanup', async () => {
    const fixture = await createFixture('delete-404');
    const cookies = await login(fixture);
    await worker.drainOnce();
    const eventId = app
      .get(CalendarSyncService)
      .deterministicEventId(fixture.appointmentId);
    provider.externalEvents.delete(eventId);

    await request(app.getHttpServer())
      .post(`/v1/admin/appointments/${fixture.appointmentId}/cancel`)
      .set('Cookie', cookies)
      .send({ version: 1 })
      .expect(201);
    await worker.drainOnce();

    const deleteOutbox = await prisma.outboxEvent.findFirstOrThrow({
      where: { aggregateId: fixture.appointmentId, type: OUTBOX_DELETE_EVENT },
    });
    expect(deleteOutbox.status).toBe(OutboxStatus.COMPLETED);
    expect((await getAppointment(fixture)).syncStatus).toBe(SyncStatus.SYNCED);
  });
});
