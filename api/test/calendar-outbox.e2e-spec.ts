// The E2E Jest config transpiles tests as CommonJS while @nestjs/schedule 12
// publishes ESM. Keep only its registry surface local to this suite; the
// outbox worker, Prisma transactions, and PostgreSQL claim remain real.
jest.mock('@nestjs/schedule', () => {
  class SchedulerRegistry {
    private readonly intervals = new Map<string, NodeJS.Timeout>();

    addInterval(name: string, interval: NodeJS.Timeout): void {
      this.intervals.set(name, interval);
    }

    deleteInterval(name: string): void {
      this.intervals.delete(name);
    }
  }

  class ScheduleModule {}

  return {
    ScheduleModule: {
      forRoot: () => ({
        module: ScheduleModule,
        providers: [SchedulerRegistry],
        exports: [SchedulerRegistry],
      }),
    },
    SchedulerRegistry,
  };
});

import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import {
  AppointmentStatus,
  CalendarConnectionStatus,
  OutboxStatus,
  Prisma,
  SyncIssueStatus,
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
  type CalendarEventInput,
  type CalendarEventResult,
  type CalendarProvider,
} from '../src/calendar/calendar.provider';
import { CalendarSyncService } from '../src/sync/calendar-sync.service';
import {
  createOutboxEventProcessor,
  OutboxWorkerService,
} from '../src/sync/outbox-worker.service';
import { SyncIssuesService } from '../src/sync/sync-issues.service';
import {
  OUTBOX_CREATE_EVENT,
  SYNC_CONFIG,
  type SyncConfig,
} from '../src/sync/sync.constants';
import { PrismaService } from '../src/database/prisma.service';

jest.setTimeout(30_000);

type ProviderMode = 'success' | 'unavailable' | 'reauth';

type Fixture = {
  artistId: string;
  clientIds: string[];
  requestIds: string[];
  appointmentIds: string[];
  outboxIds: string[];
  calendarEventIds: string[];
  connectionIds: string[];
  settingsIds: string[];
  sessionIds: string[];
  password: string;
  clientName: string;
  clientEmail: string;
  clientPhone: string;
  paymentReference: string;
};

class FakeCalendarProvider implements CalendarProvider {
  mode: ProviderMode = 'success';
  externalCreateCount = 0;
  beforeCreate: ((input: CalendarEventInput) => Promise<void>) | null = null;
  readonly externalEvents = new Map<string, CalendarEventResult>();

  readonly authorizationUrl = jest.fn(
    ({ state }: { state: string }) =>
      `https://calendar.test/authorize?state=${encodeURIComponent(state)}`,
  );

  readonly exchangeCode = jest.fn().mockResolvedValue({
    refreshToken: 'test-refresh-token',
  });

  readonly listCalendars = jest
    .fn()
    .mockResolvedValue([{ id: 'inkslot-calendar', name: 'InkSlot' }]);

  readonly freeBusy = jest.fn().mockResolvedValue([]);

  readonly createEvent = jest.fn(
    async (input: CalendarEventInput): Promise<CalendarEventResult> => {
      await this.beforeCreate?.(input);

      if (this.mode === 'reauth') {
        throw new CalendarProviderError(
          'CALENDAR_REAUTH_REQUIRED',
          'provider token must not escape',
        );
      }
      if (this.mode === 'unavailable') {
        throw new CalendarProviderError(
          'CALENDAR_UNAVAILABLE',
          'provider outage must not escape',
        );
      }

      const existing = this.externalEvents.get(input.eventId);
      if (existing) {
        throw new CalendarProviderError(
          'CALENDAR_EVENT_EXISTS',
          'external event already exists',
        );
      }

      const result = {
        externalEventId: `external-${input.eventId}`,
        etag: `etag-${input.eventId}`,
      };
      this.externalEvents.set(input.eventId, result);
      this.externalCreateCount += 1;
      return result;
    },
  );

  readonly getEvent = jest.fn(
    async (input: {
      refreshToken: string;
      calendarId: string;
      eventId: string;
    }): Promise<CalendarEventResult | null> =>
      this.externalEvents.get(input.eventId) ?? null,
  );

  readonly revoke = jest.fn().mockResolvedValue(undefined);

  reset(): void {
    this.mode = 'success';
    this.externalCreateCount = 0;
    this.beforeCreate = null;
    this.externalEvents.clear();
    this.authorizationUrl.mockClear();
    this.exchangeCode.mockClear();
    this.listCalendars.mockClear();
    this.freeBusy.mockClear();
    this.createEvent.mockClear();
    this.getEvent.mockClear();
    this.revoke.mockClear();
  }
}

const fakeProvider = new FakeCalendarProvider();

const fakeCalendarConfig: CalendarConfig = {
  configured: true,
  clientId: 'test-client-id',
  clientSecret: 'test-client-secret',
  redirectUri: 'http://localhost:3000/v1/admin/calendar/callback',
  calendarName: 'InkSlot',
  scopes: ['test-scope'],
  tokenEncryptionKey: Buffer.alloc(32),
};

const fakeCrypto = {
  encrypt: jest.fn((value: string) => `encrypted:${value}`),
  decrypt: jest.fn(() => 'test-refresh-token'),
};

const testSyncConfig: SyncConfig = {
  enabled: false,
  pollIntervalMs: 1_000,
  batchSize: 10,
  leaseMs: 120_000,
  maxAttempts: 5,
  retryBaseMs: 1_000,
  retryMaxMs: 1_000,
  jitterRatio: 0,
};

describe('calendar outbox integration', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let worker: OutboxWorkerService;
  const fixtures: Fixture[] = [];

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(CALENDAR_CONFIG)
      .useValue(fakeCalendarConfig)
      .overrideProvider(CALENDAR_PROVIDER)
      .useValue(fakeProvider)
      .overrideProvider(CalendarCrypto)
      .useValue(fakeCrypto)
      .overrideProvider(SYNC_CONFIG)
      .useValue(testSyncConfig)
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

  beforeEach(() => {
    fakeProvider.reset();
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
    const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const password = 'local-test-password';
    const clientName = `Outbox Client ${suffix}`;
    const fixture: Fixture = {
      artistId: '',
      clientIds: [],
      requestIds: [],
      appointmentIds: [],
      outboxIds: [],
      calendarEventIds: [],
      connectionIds: [],
      settingsIds: [],
      sessionIds: [],
      password,
      clientName,
      clientEmail: `private-${suffix}@example.test`,
      clientPhone: `+593999${suffix.replace(/\D/g, '').slice(-6)}`,
      paymentReference: `PAYMENT-${suffix}`,
    };

    const artist = await prisma.artist.create({
      data: {
        email: `artist-${suffix}@example.test`,
        passwordHash: await argon2.hash(password, { type: argon2.argon2id }),
        displayName: `Outbox Artist ${suffix}`,
      },
    });
    fixture.artistId = artist.id;
    fixtures.push(fixture);

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
    fixture.settingsIds.push(settings.id);

    const client = await prisma.client.create({
      data: {
        artistId: artist.id,
        name: clientName,
        email: fixture.clientEmail,
        phone: fixture.clientPhone,
      },
    });
    fixture.clientIds.push(client.id);

    const bookingRequest = await prisma.bookingRequest.create({
      data: {
        artistId: artist.id,
        clientId: client.id,
        paymentReference: fixture.paymentReference,
        durationMinutes: 90,
        status: 'PENDING',
        allowedWeekdays: [1, 3, 5] as Prisma.InputJsonValue,
        allowedWindows: [
          { startLocal: '10:00', endLocal: '18:00' },
        ] as Prisma.InputJsonValue,
      },
    });
    fixture.requestIds.push(bookingRequest.id);

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
    fixture.appointmentIds.push(appointment.id);

    const connection = await prisma.calendarConnection.create({
      data: {
        artistId: artist.id,
        calendarId: 'inkslot-calendar',
        calendarName: 'InkSlot',
        encryptedRefreshToken: 'encrypted:test-refresh-token',
        status: CalendarConnectionStatus.CONNECTED,
      },
    });
    fixture.connectionIds.push(connection.id);

    const outbox = await prisma.outboxEvent.create({
      data: {
        aggregateId: appointment.id,
        type: OUTBOX_CREATE_EVENT,
        payload: { appointmentId: appointment.id, operation: 'create' },
      },
    });
    fixture.outboxIds.push(outbox.id);

    return fixture;
  }

  async function createSupplementalAppointment(
    fixture: Fixture,
  ): Promise<string> {
    const client = await prisma.client.create({
      data: {
        artistId: fixture.artistId,
        name: `Supplemental ${fixture.artistId}`,
      },
    });
    fixture.clientIds.push(client.id);

    const bookingRequest = await prisma.bookingRequest.create({
      data: {
        artistId: fixture.artistId,
        clientId: client.id,
        durationMinutes: 60,
      },
    });
    fixture.requestIds.push(bookingRequest.id);

    const appointment = await prisma.appointment.create({
      data: {
        requestId: bookingRequest.id,
        artistId: fixture.artistId,
        startAt: new Date('2026-11-04T15:00:00.000Z'),
        endAt: new Date('2026-11-04T16:00:00.000Z'),
        status: AppointmentStatus.CONFIRMED,
        syncStatus: SyncStatus.PENDING,
      },
    });
    fixture.appointmentIds.push(appointment.id);
    return appointment.id;
  }

  async function login(fixture: Fixture): Promise<string[]> {
    const artist = await prisma.artist.findUniqueOrThrow({
      where: { id: fixture.artistId },
      select: { email: true },
    });
    const response = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: artist.email, password: fixture.password })
      .expect(200);
    const sessions = await prisma.adminSession.findMany({
      where: { artistId: fixture.artistId },
      select: { id: true },
    });
    fixture.sessionIds.push(
      ...sessions
        .map((session) => session.id)
        .filter((id) => !fixture.sessionIds.includes(id)),
    );
    return response.headers['set-cookie'] as string[];
  }

  async function cleanupFixture(fixture: Fixture): Promise<void> {
    await prisma.syncIssue.deleteMany({
      where: { appointmentId: { in: fixture.appointmentIds } },
    });
    await prisma.calendarEvent.deleteMany({
      where: { id: { in: fixture.calendarEventIds } },
    });
    await prisma.outboxEvent.deleteMany({
      where: { id: { in: fixture.outboxIds } },
    });
    await prisma.appointment.deleteMany({
      where: { id: { in: fixture.appointmentIds } },
    });
    await prisma.bookingToken.deleteMany({
      where: { requestId: { in: fixture.requestIds } },
    });
    await prisma.bookingRequest.deleteMany({
      where: { id: { in: fixture.requestIds } },
    });
    await prisma.client.deleteMany({
      where: { id: { in: fixture.clientIds } },
    });
    await prisma.calendarConnection.deleteMany({
      where: { id: { in: fixture.connectionIds } },
    });
    await prisma.studioSettings.deleteMany({
      where: { id: { in: fixture.settingsIds } },
    });
    await prisma.adminSession.deleteMany({
      where: { id: { in: fixture.sessionIds } },
    });
    await prisma.artist.delete({ where: { id: fixture.artistId } });
  }

  async function setOutboxDue(fixture: Fixture): Promise<void> {
    await prisma.outboxEvent.update({
      where: { id: fixture.outboxIds[0] },
      data: { nextAttemptAt: new Date(Date.now() - 1_000) },
    });
  }

  async function readState(fixture: Fixture) {
    const [appointment, outbox, issue, connection, calendarEvent] =
      await Promise.all([
        prisma.appointment.findUniqueOrThrow({
          where: { id: fixture.appointmentIds[0] },
        }),
        prisma.outboxEvent.findUniqueOrThrow({
          where: { id: fixture.outboxIds[0] },
        }),
        prisma.syncIssue.findFirst({
          where: { appointmentId: fixture.appointmentIds[0] },
          orderBy: { lastAttemptAt: 'desc' },
        }),
        prisma.calendarConnection.findUniqueOrThrow({
          where: { id: fixture.connectionIds[0] },
        }),
        prisma.calendarEvent.findUnique({
          where: { appointmentId: fixture.appointmentIds[0] },
        }),
      ]);
    return { appointment, outbox, issue, connection, calendarEvent };
  }

  function safeIssueMessage(message: string): void {
    expect(message).not.toContain('provider token');
    expect(message).not.toContain('test-refresh-token');
    expect(message).not.toContain('external event already exists');
  }

  it('processes a booking once and keeps event content private', async () => {
    const fixture = await createFixture();

    await worker.drainOnce();

    const state = await readState(fixture);
    expect(fakeProvider.createEvent).toHaveBeenCalledTimes(1);
    expect(fakeProvider.externalCreateCount).toBe(1);
    expect(state.calendarEvent).toMatchObject({
      appointmentId: fixture.appointmentIds[0],
      calendarId: 'inkslot-calendar',
    });
    expect(state.appointment.syncStatus).toBe(SyncStatus.SYNCED);
    expect(state.outbox.status).toBe(OutboxStatus.COMPLETED);
    expect(state.outbox.nextAttemptAt).toBeNull();
    expect(state.issue).toBeNull();

    const eventInput = fakeProvider.createEvent.mock.calls[0][0];
    const eventContent = `${eventInput.summary}\n${eventInput.description}`;
    expect(eventInput.summary).toBe(`InkSlot — ${fixture.clientName}`);
    expect(eventInput.description).toBe('Reserva InkSlot · 90 min');
    for (const privateValue of [
      fixture.clientEmail,
      fixture.clientPhone,
      fixture.paymentReference,
      fixture.artistId,
      fixture.requestIds[0],
      fixture.appointmentIds[0],
      'test-refresh-token',
    ]) {
      expect(eventContent).not.toContain(privateValue);
    }
  });

  it('requeues a transient outage and resolves it on a later drain', async () => {
    const fixture = await createFixture();
    fakeProvider.mode = 'unavailable';

    await worker.drainOnce();
    let state = await readState(fixture);
    expect(state.outbox.status).toBe(OutboxStatus.PENDING);
    expect(state.outbox.nextAttemptAt?.getTime()).toBeGreaterThan(Date.now());
    expect(state.appointment.syncStatus).toBe(SyncStatus.PENDING);
    expect(state.issue?.code).toBe('CALENDAR_UNAVAILABLE');
    expect(state.issue?.status).toBe(SyncIssueStatus.OPEN);
    safeIssueMessage(state.issue?.messageSafe ?? '');

    fakeProvider.mode = 'success';
    await setOutboxDue(fixture);
    await worker.drainOnce();

    state = await readState(fixture);
    expect(state.appointment.syncStatus).toBe(SyncStatus.SYNCED);
    expect(state.outbox.status).toBe(OutboxStatus.COMPLETED);
    expect(state.issue?.status).toBe(SyncIssueStatus.RESOLVED);
    expect(
      await prisma.syncIssue.count({
        where: {
          appointmentId: fixture.appointmentIds[0],
          status: SyncIssueStatus.OPEN,
        },
      }),
    ).toBe(0);
  });

  it('recovers after external creation and local finalization failure without duplicating', async () => {
    const fixture = await createFixture();
    const supplementalAppointmentId =
      await createSupplementalAppointment(fixture);
    const eventId = app
      .get(CalendarSyncService)
      .deterministicEventId(fixture.appointmentIds[0]);
    const conflict = await prisma.calendarEvent.create({
      data: {
        appointmentId: supplementalAppointmentId,
        calendarId: 'inkslot-calendar',
        externalEventId: `external-${eventId}`,
        etag: 'conflict-etag',
      },
    });
    fixture.calendarEventIds.push(conflict.id);

    await worker.drainOnce();
    expect(fakeProvider.externalCreateCount).toBe(1);
    expect(fakeProvider.createEvent).toHaveBeenCalledTimes(1);

    let state = await readState(fixture);
    expect(state.outbox.status).toBe(OutboxStatus.PROCESSING);
    expect(state.calendarEvent).toBeNull();
    expect(state.appointment.syncStatus).toBe(SyncStatus.PENDING);

    await prisma.calendarEvent.delete({ where: { id: conflict.id } });
    fixture.calendarEventIds = fixture.calendarEventIds.filter(
      (id) => id !== conflict.id,
    );
    await prisma.outboxEvent.update({
      where: { id: fixture.outboxIds[0] },
      data: { status: OutboxStatus.PENDING, nextAttemptAt: new Date() },
    });

    await worker.drainOnce();

    state = await readState(fixture);
    expect(fakeProvider.externalCreateCount).toBe(1);
    expect(fakeProvider.createEvent).toHaveBeenCalledTimes(2);
    expect(fakeProvider.getEvent).toHaveBeenCalledTimes(1);
    expect(state.calendarEvent).not.toBeNull();
    expect(state.appointment.syncStatus).toBe(SyncStatus.SYNCED);
    expect(state.outbox.status).toBe(OutboxStatus.COMPLETED);
  });

  it('marks reauth failures safely and requests reconnection', async () => {
    const fixture = await createFixture();
    fakeProvider.mode = 'reauth';

    await worker.drainOnce();

    const state = await readState(fixture);
    expect(state.connection.status).toBe(
      CalendarConnectionStatus.NEEDS_RECONNECT,
    );
    expect(state.appointment.syncStatus).toBe(SyncStatus.FAILED);
    expect(state.outbox.status).toBe(OutboxStatus.FAILED);
    expect(state.outbox.nextAttemptAt).toBeNull();
    expect(state.issue?.code).toBe('CALENDAR_REAUTH_REQUIRED');
    expect(state.issue?.status).toBe(SyncIssueStatus.OPEN);
    safeIssueMessage(state.issue?.messageSafe ?? '');
  });

  it('exhausts exactly five transient attempts with a safe terminal issue', async () => {
    const fixture = await createFixture();
    fakeProvider.mode = 'unavailable';

    for (let attempt = 1; attempt <= testSyncConfig.maxAttempts; attempt += 1) {
      await setOutboxDue(fixture);
      await worker.drainOnce();
      const outbox = await prisma.outboxEvent.findUniqueOrThrow({
        where: { id: fixture.outboxIds[0] },
      });
      expect(outbox.attempts).toBe(attempt);
      if (attempt < testSyncConfig.maxAttempts) {
        expect(outbox.status).toBe(OutboxStatus.PENDING);
      }
    }

    const state = await readState(fixture);
    expect(fakeProvider.createEvent).toHaveBeenCalledTimes(5);
    expect(state.outbox.status).toBe(OutboxStatus.FAILED);
    expect(state.appointment.syncStatus).toBe(SyncStatus.FAILED);
    expect(state.issue?.code).toBe('SYNC_ATTEMPTS_EXHAUSTED');
    safeIssueMessage(state.issue?.messageSafe ?? '');
  });

  it('fails safely for malformed payloads and missing appointments', async () => {
    const malformed = await createFixture();
    await prisma.outboxEvent.update({
      where: { id: malformed.outboxIds[0] },
      data: {
        payload: {
          appointmentId: malformed.appointmentIds[0],
          operation: 'update',
        },
      },
    });
    await worker.drainOnce();

    let state = await readState(malformed);
    expect(state.outbox.status).toBe(OutboxStatus.FAILED);
    expect(state.appointment.syncStatus).toBe(SyncStatus.FAILED);
    expect(state.issue?.code).toBe('OUTBOX_PAYLOAD_INVALID');
    expect(fakeProvider.createEvent).not.toHaveBeenCalled();

    const missing = await createFixture();
    const missingAppointmentId = missing.appointmentIds[0];
    await prisma.appointment.delete({ where: { id: missingAppointmentId } });
    await worker.drainOnce();

    const missingOutbox = await prisma.outboxEvent.findUniqueOrThrow({
      where: { id: missing.outboxIds[0] },
    });
    expect(missingOutbox.status).toBe(OutboxStatus.FAILED);
    expect(
      await prisma.syncIssue.count({
        where: { appointmentId: missingAppointmentId },
      }),
    ).toBe(0);
    state = await readState(malformed);
    expect(state.issue?.status).toBe(SyncIssueStatus.OPEN);
  });

  it('lets two workers claim one outbox row and create one external event', async () => {
    const fixture = await createFixture();
    let enteredResolve!: () => void;
    let releaseResolve!: () => void;
    let barrierUsed = false;
    const entered = new Promise<void>((resolve) => {
      enteredResolve = resolve;
    });
    const release = new Promise<void>((resolve) => {
      releaseResolve = resolve;
    });
    fakeProvider.beforeCreate = async () => {
      if (barrierUsed) return;
      barrierUsed = true;
      enteredResolve();
      await release;
    };

    const scheduler = {
      addInterval: jest.fn(),
      deleteInterval: jest.fn(),
    };
    const processor = createOutboxEventProcessor(
      app.get(CalendarSyncService),
      app.get(SyncIssuesService),
      testSyncConfig,
    );
    const workerOne = new OutboxWorkerService(
      prisma,
      testSyncConfig,
      scheduler,
      processor,
    );
    const workerTwo = new OutboxWorkerService(
      prisma,
      testSyncConfig,
      scheduler,
      processor,
    );

    const first = workerOne.drainOnce();
    await entered;
    const second = workerTwo.drainOnce();
    await new Promise((resolve) => setTimeout(resolve, 25));
    releaseResolve();
    await Promise.all([first, second]);
    await workerOne.beforeApplicationShutdown();
    await workerTwo.beforeApplicationShutdown();

    const state = await readState(fixture);
    expect(fakeProvider.externalCreateCount).toBe(1);
    expect(fakeProvider.createEvent).toHaveBeenCalledTimes(1);
    expect(state.calendarEvent).not.toBeNull();
    expect(state.appointment.syncStatus).toBe(SyncStatus.SYNCED);
    expect(state.outbox.status).toBe(OutboxStatus.COMPLETED);
  });

  it('scopes admin issues by owner and only the owner can retry', async () => {
    const owner = await createFixture();
    const other = await createFixture();
    const ownerCookies = await login(owner);
    const otherCookies = await login(other);
    fakeProvider.mode = 'unavailable';

    await worker.drainOnce();
    await setOutboxDue(other);
    await worker.drainOnce();

    const ownerIssues = await request(app.getHttpServer())
      .get('/v1/admin/sync-issues')
      .set('Cookie', ownerCookies)
      .expect(200);
    const otherIssues = await request(app.getHttpServer())
      .get('/v1/admin/sync-issues')
      .set('Cookie', otherCookies)
      .expect(200);
    const ownerIssueId = ownerIssues.body.items[0].id as string;
    const otherIssueId = otherIssues.body.items[0].id as string;
    expect(ownerIssues.body.items).toEqual([
      expect.objectContaining({ appointmentId: owner.appointmentIds[0] }),
    ]);
    expect(otherIssues.body.items).toEqual([
      expect.objectContaining({ appointmentId: other.appointmentIds[0] }),
    ]);

    const otherBefore = await readState(other);
    await request(app.getHttpServer())
      .post(`/v1/admin/sync-issues/${otherIssueId}/retry`)
      .set('Cookie', ownerCookies)
      .expect(404);
    const otherAfterForeignRetry = await readState(other);
    expect(otherAfterForeignRetry.outbox.status).toBe(
      otherBefore.outbox.status,
    );
    expect(otherAfterForeignRetry.appointment.syncStatus).toBe(
      otherBefore.appointment.syncStatus,
    );

    fakeProvider.mode = 'success';
    await request(app.getHttpServer())
      .post(`/v1/admin/sync-issues/${ownerIssueId}/retry`)
      .set('Cookie', ownerCookies)
      .expect(200)
      .expect({ status: 'queued' });
    await worker.drainOnce();

    const ownerAfter = await readState(owner);
    expect(ownerAfter.outbox.status).toBe(OutboxStatus.COMPLETED);
    expect(ownerAfter.appointment.syncStatus).toBe(SyncStatus.SYNCED);
    expect(ownerAfter.issue?.status).toBe(SyncIssueStatus.RESOLVED);
  });
});
