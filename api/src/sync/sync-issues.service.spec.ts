import {
  INestApplication,
  UnauthorizedException,
  ValidationPipe,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import {
  CalendarConnectionStatus,
  OutboxStatus,
  SyncIssueStatus,
  SyncStatus,
} from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import { AdminSessionGuard } from '../auth/admin-session.guard';
import { AuthService } from '../auth/auth.service';
import type { CalendarSyncSuccess } from './calendar-sync.service';
import { SyncIssuesController } from './sync-issues.controller';
import { ListSyncIssuesDto } from './sync-issues.dto';
import { SyncIssuesService } from './sync-issues.service';
import {
  OUTBOX_CREATE_EVENT,
  type ClaimedOutboxEvent,
  type SyncConfig,
  type SyncFailure,
} from './sync.constants';

describe('SyncIssuesService', () => {
  const appointmentId = '44444444-4444-4444-8444-444444444444';
  const outboxId = '55555555-5555-4555-8555-555555555555';
  const artistId = '11111111-1111-4111-8111-111111111111';
  const now = new Date('2026-10-16T12:00:00.000Z');
  const config: SyncConfig = {
    enabled: false,
    pollIntervalMs: 5_000,
    batchSize: 10,
    leaseMs: 120_000,
    maxAttempts: 3,
    retryBaseMs: 100,
    retryMaxMs: 1_000,
    jitterRatio: 0.2,
  };
  const event: ClaimedOutboxEvent = {
    id: outboxId,
    aggregateId: appointmentId,
    type: OUTBOX_CREATE_EVENT,
    payload: { appointmentId, operation: 'create' },
    attempts: 1,
  };
  const success: CalendarSyncSuccess = {
    appointmentId,
    calendarId: 'inkslot-calendar',
    externalEventId: 'google-event-id',
    etag: 'etag-1',
  };

  let transaction: Record<string, Record<string, jest.Mock>>;
  let prisma: {
    $transaction: jest.Mock;
    syncIssue: { findMany: jest.Mock };
  };
  let service: SyncIssuesService;

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(now);
    transaction = {
      calendarEvent: {
        create: jest.fn(),
        findUnique: jest.fn(),
      },
      appointment: {
        findUnique: jest.fn().mockResolvedValue({ artistId }),
        update: jest.fn(),
      },
      outboxEvent: {
        findFirst: jest.fn().mockResolvedValue({ id: outboxId }),
        update: jest.fn(),
      },
      syncIssue: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      calendarConnection: { updateMany: jest.fn() },
    };
    prisma = {
      $transaction: jest.fn(),
      syncIssue: { findMany: jest.fn() },
    };
    prisma.$transaction.mockImplementation(async (callback) =>
      callback(transaction),
    );
    service = new SyncIssuesService(
      prisma as unknown as PrismaService,
      () => 0.5,
    );
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('lists only scoped open issues with safe fields, bounded ordering, and a default status', async () => {
    const firstCreatedAt = new Date('2026-10-01T10:00:00.000Z');
    const secondCreatedAt = new Date('2026-10-02T10:00:00.000Z');
    const lastAttemptAt = new Date('2026-10-16T11:00:00.000Z');
    const query = new ListSyncIssuesDto();
    const findMany = (prisma.syncIssue.findMany as jest.Mock).mockResolvedValue(
      [
        {
          id: 'issue-1',
          appointmentId,
          operation: OUTBOX_CREATE_EVENT,
          code: 'CALENDAR_UNAVAILABLE',
          messageSafe: 'Mensaje seguro',
          status: SyncIssueStatus.OPEN,
          lastAttemptAt,
          appointment: { createdAt: firstCreatedAt },
        },
        {
          id: 'issue-2',
          appointmentId: '66666666-6666-4666-8666-666666666666',
          operation: OUTBOX_CREATE_EVENT,
          code: 'CALENDAR_REAUTH_REQUIRED',
          messageSafe: 'Reconecta Calendar',
          status: SyncIssueStatus.OPEN,
          lastAttemptAt: null,
          appointment: { createdAt: secondCreatedAt },
        },
      ],
    );

    await expect(service.list(artistId, query)).resolves.toEqual({
      items: [
        {
          id: 'issue-1',
          appointmentId,
          operation: OUTBOX_CREATE_EVENT,
          code: 'CALENDAR_UNAVAILABLE',
          message: 'Mensaje seguro',
          status: 'open',
          lastAttemptAt: lastAttemptAt.toISOString(),
          createdAt: firstCreatedAt.toISOString(),
        },
        {
          id: 'issue-2',
          appointmentId: '66666666-6666-4666-8666-666666666666',
          operation: OUTBOX_CREATE_EVENT,
          code: 'CALENDAR_REAUTH_REQUIRED',
          message: 'Reconecta Calendar',
          status: 'open',
          lastAttemptAt: null,
          createdAt: secondCreatedAt.toISOString(),
        },
      ],
    });

    expect(findMany).toHaveBeenCalledWith({
      where: {
        operation: OUTBOX_CREATE_EVENT,
        status: SyncIssueStatus.OPEN,
        appointment: { artistId },
      },
      orderBy: [
        { lastAttemptAt: { sort: 'desc', nulls: 'last' } },
        { appointment: { createdAt: 'desc' } },
      ],
      take: 50,
      select: {
        id: true,
        appointmentId: true,
        operation: true,
        code: true,
        messageSafe: true,
        status: true,
        lastAttemptAt: true,
        appointment: { select: { createdAt: true } },
      },
    });
    expect(JSON.stringify(findMany.mock.calls)).not.toContain('payment');
    expect(JSON.stringify(findMany.mock.calls)).not.toContain('token');
  });

  it('filters resolved issues when explicitly requested and keeps the response bounded to 50', async () => {
    const resolved = new ListSyncIssuesDto();
    resolved.status = 'resolved';
    (prisma.syncIssue.findMany as jest.Mock).mockResolvedValue([]);

    await service.list(artistId, resolved);

    expect(prisma.syncIssue.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: SyncIssueStatus.RESOLVED }),
        take: 50,
      }),
    );
  });

  it('rejects a foreign issue without changing its outbox or appointment', async () => {
    transaction.syncIssue.findFirst.mockResolvedValue(null);

    await expect(
      service.retry(artistId, 'foreign-issue'),
    ).rejects.toMatchObject({
      response: {
        error: { code: 'NOT_FOUND', message: 'Incidencia no encontrada' },
      },
    });
    expect(transaction.outboxEvent.update).not.toHaveBeenCalled();
    expect(transaction.appointment.update).not.toHaveBeenCalled();
  });

  it('requeues the owner outbox and is idempotent when retried again', async () => {
    transaction.syncIssue.findFirst.mockResolvedValue({ appointmentId });

    await expect(service.retry(artistId, 'issue-1')).resolves.toEqual({
      status: 'queued',
    });
    await expect(service.retry(artistId, 'issue-1')).resolves.toEqual({
      status: 'queued',
    });

    expect(transaction.syncIssue.findFirst).toHaveBeenCalledWith({
      where: {
        id: 'issue-1',
        operation: OUTBOX_CREATE_EVENT,
        status: SyncIssueStatus.OPEN,
        appointment: { artistId },
      },
      select: { appointmentId: true },
    });
    expect(transaction.outboxEvent.findFirst).toHaveBeenCalledWith({
      where: { aggregateId: appointmentId, type: OUTBOX_CREATE_EVENT },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });
    expect(transaction.outboxEvent.update).toHaveBeenCalledTimes(2);
    expect(transaction.outboxEvent.update).toHaveBeenCalledWith({
      where: { id: outboxId },
      data: {
        status: OutboxStatus.PENDING,
        attempts: 0,
        nextAttemptAt: now,
      },
    });
    expect(transaction.appointment.update).toHaveBeenCalledTimes(2);
  });

  it('persists every success transition in one transaction', async () => {
    await service.finalizeSuccess(outboxId, success);

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(transaction.calendarEvent.create).toHaveBeenCalledWith({
      data: {
        appointmentId,
        calendarId: success.calendarId,
        externalEventId: success.externalEventId,
        etag: success.etag,
        lastSyncedAt: now,
      },
    });
    expect(transaction.appointment.update).toHaveBeenCalledWith({
      where: { id: appointmentId },
      data: { syncStatus: SyncStatus.SYNCED },
    });
    expect(transaction.outboxEvent.update).toHaveBeenCalledWith({
      where: { id: outboxId },
      data: { status: OutboxStatus.COMPLETED, nextAttemptAt: null },
    });
    expect(transaction.syncIssue.updateMany).toHaveBeenCalledWith({
      where: {
        appointmentId,
        operation: OUTBOX_CREATE_EVENT,
        status: SyncIssueStatus.OPEN,
      },
      data: { status: SyncIssueStatus.RESOLVED },
    });
  });

  it('rereads an existing CalendarEvent after a unique race and finalizes idempotently', async () => {
    const uniqueError = Object.assign(new Error('private detail'), {
      code: 'P2002',
    });
    prisma.$transaction
      .mockRejectedValueOnce(uniqueError)
      .mockImplementationOnce(async (callback) => callback(transaction));
    transaction.calendarEvent.findUnique.mockResolvedValue({
      appointmentId,
    });

    await expect(
      service.finalizeSuccess(outboxId, success),
    ).resolves.toBeUndefined();

    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expect(transaction.calendarEvent.create).not.toHaveBeenCalled();
    expect(transaction.appointment.update).toHaveBeenCalledWith({
      where: { id: appointmentId },
      data: { syncStatus: SyncStatus.SYNCED },
    });
  });

  it('retries temporary unavailability with exponential backoff and controlled jitter', async () => {
    const failure: SyncFailure = {
      code: 'CALENDAR_UNAVAILABLE',
      message: 'provider detail must not persist',
      retryable: true,
    };
    service = new SyncIssuesService(
      prisma as unknown as PrismaService,
      () => 0,
    );

    await service.finalizeFailure(event, failure, config);

    const update = transaction.outboxEvent.update.mock.calls[0][0];
    expect(update.data.nextAttemptAt).toEqual(
      new Date('2026-10-16T12:00:00.080Z'),
    );
    expect(update.data.status).toBe(OutboxStatus.PENDING);
    expect(transaction.appointment.update).toHaveBeenCalledWith({
      where: { id: appointmentId },
      data: { syncStatus: SyncStatus.PENDING },
    });
    expect(transaction.syncIssue.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        appointmentId,
        operation: OUTBOX_CREATE_EVENT,
        code: 'CALENDAR_UNAVAILABLE',
        messageSafe: 'No fue posible sincronizar el evento con Google Calendar',
        status: SyncIssueStatus.OPEN,
        lastAttemptAt: now,
      }),
    });
    expect(
      JSON.stringify(transaction.syncIssue.create.mock.calls),
    ).not.toContain('provider detail');
  });

  it('marks exhausted retries as terminal with a safe exhausted code', async () => {
    const failure: SyncFailure = {
      code: 'CALENDAR_UNAVAILABLE',
      message: 'raw provider response',
      retryable: true,
    };

    await service.finalizeFailure(
      { ...event, attempts: config.maxAttempts },
      failure,
      config,
    );

    expect(transaction.outboxEvent.update).toHaveBeenCalledWith({
      where: { id: outboxId },
      data: { status: OutboxStatus.FAILED, nextAttemptAt: null },
    });
    expect(transaction.appointment.update).toHaveBeenCalledWith({
      where: { id: appointmentId },
      data: { syncStatus: SyncStatus.FAILED },
    });
    expect(transaction.syncIssue.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        code: 'SYNC_ATTEMPTS_EXHAUSTED',
        messageSafe: 'Se agotaron los intentos de sincronización',
      }),
    });
  });

  it('marks reauthentication as failed and requires reconnect', async () => {
    await service.finalizeFailure(
      event,
      {
        code: 'CALENDAR_REAUTH_REQUIRED',
        message: 'raw auth response',
        retryable: false,
      },
      config,
    );

    expect(transaction.calendarConnection.updateMany).toHaveBeenCalledWith({
      where: { artistId },
      data: { status: CalendarConnectionStatus.NEEDS_RECONNECT },
    });
    expect(transaction.syncIssue.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        code: 'CALENDAR_REAUTH_REQUIRED',
        messageSafe: 'La conexión de Google requiere autorización nuevamente',
      }),
    });
  });

  it.each([
    [
      'OUTBOX_PAYLOAD_INVALID',
      'El evento de sincronización no tiene un payload válido',
    ],
    ['APPOINTMENT_NOT_FOUND', 'La reserva no existe'],
  ] as const)(
    'persists safe terminal failure for %s',
    async (code, message) => {
      await service.finalizeFailure(
        event,
        { code, message: 'untrusted raw error', retryable: false },
        config,
      );

      expect(transaction.outboxEvent.update).toHaveBeenCalledWith({
        where: { id: outboxId },
        data: { status: OutboxStatus.FAILED, nextAttemptAt: null },
      });
      expect(transaction.syncIssue.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ code, messageSafe: message }),
      });
    },
  );

  it('does not create an orphan issue when the appointment is missing', async () => {
    transaction.appointment.findUnique.mockResolvedValue(null);

    await service.finalizeFailure(
      event,
      {
        code: 'APPOINTMENT_NOT_FOUND',
        message: 'La reserva no existe',
        retryable: false,
      },
      config,
    );

    expect(transaction.outboxEvent.update).toHaveBeenCalled();
    expect(transaction.appointment.update).not.toHaveBeenCalled();
    expect(transaction.syncIssue.create).not.toHaveBeenCalled();
  });

  it('updates one existing open issue instead of creating another one', async () => {
    transaction.syncIssue.findFirst.mockResolvedValue({ id: 'issue-1' });

    await service.finalizeFailure(
      event,
      {
        code: 'CALENDAR_UNAVAILABLE',
        message: 'safe',
        retryable: true,
      },
      config,
    );

    expect(transaction.syncIssue.create).not.toHaveBeenCalled();
    expect(transaction.syncIssue.update).toHaveBeenCalledWith({
      where: { id: 'issue-1' },
      data: expect.objectContaining({
        code: 'CALENDAR_UNAVAILABLE',
        messageSafe: 'No fue posible sincronizar el evento con Google Calendar',
      }),
    });
  });
});

describe('SyncIssuesController', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [SyncIssuesController],
      providers: [
        AdminSessionGuard,
        {
          provide: AuthService,
          useValue: {
            me: jest.fn().mockRejectedValue(
              new UnauthorizedException({
                error: {
                  code: 'AUTH_INVALID',
                  message: 'Credenciales inválidas',
                },
              }),
            ),
          },
        },
        {
          provide: SyncIssuesService,
          useValue: { list: jest.fn(), retry: jest.fn() },
        },
      ],
    }).compile();

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
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects unauthenticated access with 401', async () => {
    await request(app.getHttpServer()).get('/v1/admin/sync-issues').expect(401);
  });
});
