import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import {
  AppointmentStatus,
  BookingRequestStatus,
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
  type CalendarBusyInterval,
  type CalendarBusyQuery,
  type CalendarEventInput,
  type CalendarEventResult,
  type CalendarProvider,
} from '../src/calendar/calendar.provider';
import { PrismaService } from '../src/database/prisma.service';
import { OutboxWorkerService } from '../src/sync/outbox-worker.service';
import {
  OUTBOX_CREATE_EVENT,
  SYNC_CONFIG,
  type SyncConfig,
} from '../src/sync/sync.constants';

jest.setTimeout(30_000);

class FakeCalendarProvider implements CalendarProvider {
  readonly externalEvents = new Map<string, CalendarEventResult>();

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
    void input;
    return [];
  }

  async createEvent(input: CalendarEventInput): Promise<CalendarEventResult> {
    const result = {
      externalEventId: input.eventId,
      etag: `etag-${input.eventId}`,
    };
    this.externalEvents.set(input.eventId, result);
    return result;
  }

  async updateEvent(input: CalendarEventInput): Promise<CalendarEventResult> {
    return this.createEvent(input);
  }

  async deleteEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<void> {
    this.externalEvents.delete(input.eventId);
  }

  async getEvent(input: {
    refreshToken: string;
    calendarId: string;
    eventId: string;
  }): Promise<CalendarEventResult | null> {
    return this.externalEvents.get(input.eventId) ?? null;
  }

  async revoke(): Promise<void> {}
}

type Fixture = {
  artistId: string;
  email: string;
  password: string;
  settingsId: string;
  clientIds: string[];
  requestIds: string[];
  appointmentIds: string[];
  outboxIds: string[];
  sessionIds: string[];
  calendarConnectionId?: string;
};

const calendarProvider = new FakeCalendarProvider();
const calendarConfig: CalendarConfig = {
  configured: true,
  clientId: 'test-client-id',
  clientSecret: 'test-client-secret',
  redirectUri: 'http://localhost:3000/v1/admin/calendar/callback',
  calendarName: 'InkSlot',
  scopes: ['test-scope'],
  tokenEncryptionKey: Buffer.alloc(32),
};
const calendarCrypto = {
  encrypt: jest.fn((value: string) => `encrypted:${value}`),
  decrypt: jest.fn(() => 'test-refresh-token'),
};
const syncConfig: SyncConfig = {
  enabled: false,
  pollIntervalMs: 1_000,
  batchSize: 10,
  leaseMs: 120_000,
  maxAttempts: 5,
  retryBaseMs: 1_000,
  retryMaxMs: 1_000,
  jitterRatio: 0,
};

describe('admin dashboard and sync issues', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let worker: OutboxWorkerService;
  const fixtures: Fixture[] = [];

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(CALENDAR_CONFIG)
      .useValue(calendarConfig)
      .overrideProvider(CALENDAR_PROVIDER)
      .useValue(calendarProvider)
      .overrideProvider(CalendarCrypto)
      .useValue(calendarCrypto)
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

  beforeEach(() => calendarProvider.externalEvents.clear());

  afterEach(async () => {
    while (fixtures.length > 0) {
      const fixture = fixtures.pop();
      if (fixture) await cleanupFixture(fixture);
    }
  });

  afterAll(async () => app.close());

  async function createFixture(
    label: string,
    options: { calendar?: boolean } = {},
  ): Promise<Fixture> {
    const suffix = `${label}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const password = 'local-test-password';
    const artist = await prisma.artist.create({
      data: {
        email: `admin-dashboard-${suffix}@example.test`,
        passwordHash: await argon2.hash(password, { type: argon2.argon2id }),
        displayName: `Dashboard Artist ${suffix}`,
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
    const fixture: Fixture = {
      artistId: artist.id,
      email: artist.email,
      password,
      settingsId: settings.id,
      clientIds: [],
      requestIds: [],
      appointmentIds: [],
      outboxIds: [],
      sessionIds: [],
    };
    if (options.calendar) {
      const connection = await prisma.calendarConnection.create({
        data: {
          artistId: artist.id,
          calendarId: 'inkslot-calendar',
          calendarName: 'InkSlot',
          encryptedRefreshToken: 'encrypted:test-refresh-token',
          status: CalendarConnectionStatus.CONNECTED,
        },
      });
      fixture.calendarConnectionId = connection.id;
    }
    fixtures.push(fixture);
    return fixture;
  }

  async function createRequest(
    fixture: Fixture,
    options: { status?: BookingRequestStatus; clientName?: string } = {},
  ): Promise<string> {
    const suffix = `${fixture.artistId}-${fixture.requestIds.length}`;
    const client = await prisma.client.create({
      data: {
        artistId: fixture.artistId,
        name: options.clientName ?? `Client ${suffix}`,
        email: `private-${suffix}@example.test`,
        phone: '+593999000000',
      },
    });
    fixture.clientIds.push(client.id);
    const bookingRequest = await prisma.bookingRequest.create({
      data: {
        artistId: fixture.artistId,
        clientId: client.id,
        paymentReference: `PAYMENT-${suffix}`,
        durationMinutes: 90,
        status: options.status ?? BookingRequestStatus.BOOKED,
        allowedWeekdays: [1, 3, 5] as Prisma.InputJsonValue,
        allowedWindows: [
          { startLocal: '10:00', endLocal: '18:00' },
        ] as Prisma.InputJsonValue,
      },
    });
    fixture.requestIds.push(bookingRequest.id);
    return bookingRequest.id;
  }

  async function createAppointment(
    fixture: Fixture,
    options: {
      startAt: string;
      status?: AppointmentStatus;
      clientName?: string;
      syncStatus?: SyncStatus;
    },
  ): Promise<string> {
    const requestId = await createRequest(fixture, {
      clientName: options.clientName,
    });
    const appointment = await prisma.appointment.create({
      data: {
        requestId,
        artistId: fixture.artistId,
        startAt: new Date(options.startAt),
        endAt: new Date(new Date(options.startAt).getTime() + 90 * 60 * 1000),
        status: options.status ?? AppointmentStatus.CONFIRMED,
        syncStatus: options.syncStatus ?? SyncStatus.PENDING,
      },
    });
    fixture.appointmentIds.push(appointment.id);
    return appointment.id;
  }

  async function createPendingRequest(fixture: Fixture): Promise<void> {
    await createRequest(fixture, { status: BookingRequestStatus.PENDING });
  }

  async function createOpenIssue(
    fixture: Fixture,
    appointmentId: string,
    options: { outbox?: boolean } = {},
  ): Promise<string> {
    let outboxId: string | undefined;
    if (options.outbox ?? true) {
      const outbox = await prisma.outboxEvent.create({
        data: {
          aggregateId: appointmentId,
          type: OUTBOX_CREATE_EVENT,
          payload: { appointmentId, operation: 'create' },
          status: OutboxStatus.FAILED,
          attempts: syncConfig.maxAttempts,
        },
      });
      outboxId = outbox.id;
      fixture.outboxIds.push(outbox.id);
    }
    await prisma.syncIssue.create({
      data: {
        appointmentId,
        operation: OUTBOX_CREATE_EVENT,
        code: 'CALENDAR_UNAVAILABLE',
        messageSafe: 'No fue posible sincronizar el evento con Google Calendar',
        status: SyncIssueStatus.OPEN,
      },
    });
    return outboxId ?? '';
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
      where: { appointmentId: { in: fixture.appointmentIds } },
    });
    await prisma.outboxEvent.deleteMany({
      where: { aggregateId: { in: fixture.appointmentIds } },
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
    if (fixture.calendarConnectionId) {
      await prisma.calendarConnection.delete({
        where: { id: fixture.calendarConnectionId },
      });
    }
    await prisma.studioSettings.delete({ where: { id: fixture.settingsId } });
    await prisma.adminSession.deleteMany({
      where: { id: { in: fixture.sessionIds } },
    });
    await prisma.artist.delete({ where: { id: fixture.artistId } });
  }

  it('returns a scoped dashboard with counts and five ordered appointments', async () => {
    const owner = await createFixture('owner');
    const other = await createFixture('other');
    const ownerStarts = [
      '2099-01-06T15:00:00.000Z',
      '2099-01-01T15:00:00.000Z',
      '2099-01-04T15:00:00.000Z',
      '2099-01-02T15:00:00.000Z',
      '2099-01-05T15:00:00.000Z',
      '2099-01-03T15:00:00.000Z',
    ];
    for (const [index, startAt] of ownerStarts.entries()) {
      await createAppointment(owner, {
        startAt,
        clientName: `Cliente propio ${index + 1}`,
      });
    }
    await createAppointment(owner, {
      startAt: '2020-01-01T15:00:00.000Z',
      clientName: 'Cliente pasado',
    });
    await createAppointment(owner, {
      startAt: '2099-01-20T15:00:00.000Z',
      status: AppointmentStatus.CANCELLED,
      clientName: 'Cliente cancelado',
    });
    await createPendingRequest(owner);
    const ownerIssueAppointmentId = await createAppointment(owner, {
      startAt: '2099-02-01T15:00:00.000Z',
      clientName: 'Cliente con incidencia',
    });
    await createOpenIssue(owner, ownerIssueAppointmentId, { outbox: false });

    await createPendingRequest(other);
    const otherAppointmentId = await createAppointment(other, {
      startAt: '2099-01-01T15:00:00.000Z',
      clientName: 'Cliente ajeno',
    });
    await createOpenIssue(other, otherAppointmentId, { outbox: false });

    const ownerCookies = await login(owner);
    await login(other);

    await request(app.getHttpServer())
      .get('/v1/admin/dashboard')
      .set('Cookie', ownerCookies)
      .expect(200)
      .expect((response) => {
        expect(response.body.pendingRequests).toBe(1);
        expect(response.body.upcomingAppointments).toBe(7);
        expect(response.body.syncIssues).toBe(1);
        expect(response.body.nextAppointments).toHaveLength(5);
        expect(
          response.body.nextAppointments.map(
            (item: { startAt: string }) => item.startAt,
          ),
        ).toEqual([
          '2099-01-01T15:00:00.000Z',
          '2099-01-02T15:00:00.000Z',
          '2099-01-03T15:00:00.000Z',
          '2099-01-04T15:00:00.000Z',
          '2099-01-05T15:00:00.000Z',
        ]);
        expect(
          response.body.nextAppointments.every(
            (item: { status: string }) => item.status === 'confirmed',
          ),
        ).toBe(true);
        expect(JSON.stringify(response.body)).not.toContain('paymentReference');
        expect(JSON.stringify(response.body)).not.toContain('refresh-token');
        expect(JSON.stringify(response.body)).not.toContain('Cliente ajeno');
      });
  });

  it('returns an empty dashboard for an artist without activity', async () => {
    const fixture = await createFixture('empty');
    const cookies = await login(fixture);

    await request(app.getHttpServer())
      .get('/v1/admin/dashboard')
      .set('Cookie', cookies)
      .expect(200)
      .expect({
        pendingRequests: 0,
        upcomingAppointments: 0,
        syncIssues: 0,
        nextAppointments: [],
      });
  });

  it('rejects dashboard access without an admin session', async () => {
    await request(app.getHttpServer())
      .get('/v1/admin/dashboard')
      .expect(401)
      .expect({
        error: { code: 'AUTH_INVALID', message: 'Credenciales inválidas' },
      });
  });

  it('isolates sync issues and queues retry until the worker resolves it', async () => {
    const owner = await createFixture('issue-owner', { calendar: true });
    const other = await createFixture('issue-other');
    const ownerAppointmentId = await createAppointment(owner, {
      startAt: '2099-03-01T15:00:00.000Z',
      clientName: 'Cliente con retry',
      syncStatus: SyncStatus.FAILED,
    });
    const otherAppointmentId = await createAppointment(other, {
      startAt: '2099-03-02T15:00:00.000Z',
      clientName: 'Cliente de otro artista',
      syncStatus: SyncStatus.FAILED,
    });
    await createOpenIssue(owner, ownerAppointmentId);
    await createOpenIssue(other, otherAppointmentId, { outbox: false });

    const ownerCookies = await login(owner);
    const otherCookies = await login(other);
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
      expect.objectContaining({ appointmentId: ownerAppointmentId }),
    ]);
    expect(otherIssues.body.items).toEqual([
      expect.objectContaining({ appointmentId: otherAppointmentId }),
    ]);

    await request(app.getHttpServer())
      .post(`/v1/admin/sync-issues/${otherIssueId}/retry`)
      .set('Cookie', ownerCookies)
      .expect(404);

    await request(app.getHttpServer())
      .post(`/v1/admin/sync-issues/${ownerIssueId}/retry`)
      .set('Cookie', ownerCookies)
      .expect(200)
      .expect({ status: 'queued' });

    await request(app.getHttpServer())
      .get('/v1/admin/dashboard')
      .set('Cookie', ownerCookies)
      .expect(200)
      .expect((response) => expect(response.body.syncIssues).toBe(1));

    await worker.drainOnce();

    await request(app.getHttpServer())
      .get('/v1/admin/dashboard')
      .set('Cookie', ownerCookies)
      .expect(200)
      .expect((response) => expect(response.body.syncIssues).toBe(0));
    await request(app.getHttpServer())
      .get('/v1/admin/sync-issues?status=resolved')
      .set('Cookie', ownerCookies)
      .expect(200)
      .expect((response) => {
        expect(response.body.items).toEqual([
          expect.objectContaining({
            id: ownerIssueId,
            appointmentId: ownerAppointmentId,
            status: 'resolved',
          }),
        ]);
      });
  });
});
