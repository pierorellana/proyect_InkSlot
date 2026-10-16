import type { PrismaService } from '../database/prisma.service';
import { CalendarProviderError } from '../calendar/calendar.provider';
import { CalendarSyncError } from './calendar-sync.service';
import {
  OUTBOX_WORKER_INTERVAL,
  type ClaimedOutboxEvent,
  type OutboxEventProcessor,
  type SchedulerRegistryPort,
  type SyncConfig,
} from './sync.constants';
import {
  createOutboxEventProcessor,
  OutboxWorkerService,
} from './outbox-worker.service';
import type { SyncIssuesService } from './sync-issues.service';

describe('OutboxWorkerService', () => {
  const config: SyncConfig = {
    enabled: true,
    pollIntervalMs: 5_000,
    batchSize: 2,
    leaseMs: 120_000,
    maxAttempts: 5,
    retryBaseMs: 30_000,
    retryMaxMs: 900_000,
    jitterRatio: 0.2,
  };
  const firstEvent: ClaimedOutboxEvent = {
    id: 'outbox-1',
    aggregateId: 'appointment-1',
    type: 'appointment.calendar.create',
    payload: { appointmentId: 'appointment-1', operation: 'create' },
    attempts: 1,
  };
  const secondEvent: ClaimedOutboxEvent = {
    ...firstEvent,
    id: 'outbox-2',
    aggregateId: 'appointment-2',
    payload: { appointmentId: 'appointment-2', operation: 'create' },
  };

  let prisma: { $transaction: jest.Mock };
  let transaction: { $queryRaw: jest.Mock };
  let scheduler: jest.Mocked<SchedulerRegistryPort>;
  let processor: jest.MockedFunction<OutboxEventProcessor>;
  let worker: OutboxWorkerService;

  beforeEach(() => {
    transaction = { $queryRaw: jest.fn() };
    prisma = { $transaction: jest.fn() };
    prisma.$transaction.mockImplementation(async (callback) =>
      callback(transaction),
    );
    scheduler = {
      addInterval: jest.fn(),
      deleteInterval: jest.fn(),
    };
    processor = jest.fn().mockResolvedValue(undefined);
    worker = new OutboxWorkerService(
      prisma as unknown as PrismaService,
      config,
      scheduler,
      processor,
    );
  });

  it('claims due and stale rows in batches and passes typed events to the processor', async () => {
    transaction.$queryRaw
      .mockResolvedValueOnce([
        {
          id: firstEvent.id,
          aggregate_id: firstEvent.aggregateId,
          type: firstEvent.type,
          payload: firstEvent.payload,
          attempts: firstEvent.attempts,
        },
      ])
      .mockResolvedValueOnce([
        {
          id: secondEvent.id,
          aggregate_id: secondEvent.aggregateId,
          type: secondEvent.type,
          payload: secondEvent.payload,
          attempts: secondEvent.attempts,
        },
      ]);

    await expect(worker.drainOnce()).resolves.toBe(2);

    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expect(processor).toHaveBeenNthCalledWith(1, firstEvent);
    expect(processor).toHaveBeenNthCalledWith(2, secondEvent);

    const query = transaction.$queryRaw.mock.calls[0][0] as {
      sql: string;
      values: unknown[];
    };
    expect(query.sql).toContain('FOR UPDATE SKIP LOCKED');
    expect(query.sql).toContain('LIMIT 1');
    expect(query.sql).toContain("status = 'PENDING'");
    expect(query.sql).toContain("status = 'PROCESSING'");
    expect(query.values).toContain(config.leaseMs);
  });

  it('keeps draining after one processor failure', async () => {
    config.batchSize = 2;
    transaction.$queryRaw
      .mockResolvedValueOnce([
        {
          id: firstEvent.id,
          aggregate_id: firstEvent.aggregateId,
          type: firstEvent.type,
          payload: firstEvent.payload,
          attempts: firstEvent.attempts,
        },
      ])
      .mockResolvedValueOnce([
        {
          id: secondEvent.id,
          aggregate_id: secondEvent.aggregateId,
          type: secondEvent.type,
          payload: secondEvent.payload,
          attempts: secondEvent.attempts,
        },
      ]);
    processor
      .mockRejectedValueOnce(new Error('provider detail'))
      .mockResolvedValueOnce(undefined);

    await expect(worker.drainOnce()).resolves.toBe(2);
    expect(processor).toHaveBeenCalledTimes(2);
  });

  it('composes CalendarSyncService and SyncIssuesService into the real processor', async () => {
    const calendarSync = {
      process: jest.fn().mockResolvedValue({
        appointmentId: firstEvent.aggregateId,
        calendarId: 'calendar-1',
        externalEventId: 'event-1',
        etag: null,
      }),
    };
    const syncIssues = {
      finalizeSuccess: jest.fn().mockResolvedValue(undefined),
      finalizeFailure: jest.fn().mockResolvedValue(undefined),
    };
    const realProcessor = createOutboxEventProcessor(
      calendarSync as never,
      syncIssues as unknown as SyncIssuesService,
      config,
    );

    await realProcessor(firstEvent);

    expect(calendarSync.process).toHaveBeenCalledWith(firstEvent);
    expect(syncIssues.finalizeSuccess).toHaveBeenCalledWith(firstEvent.id, {
      appointmentId: firstEvent.aggregateId,
      calendarId: 'calendar-1',
      externalEventId: 'event-1',
      etag: null,
    });
    expect(syncIssues.finalizeFailure).not.toHaveBeenCalled();
  });

  it('converts handler failures to safe finalization without rejecting the processor', async () => {
    const calendarSync = {
      process: jest.fn().mockRejectedValue(
        new CalendarSyncError({
          code: 'CALENDAR_UNAVAILABLE',
          message: 'private provider detail',
          retryable: true,
        }),
      ),
    };
    const syncIssues = {
      finalizeSuccess: jest.fn(),
      finalizeFailure: jest.fn().mockResolvedValue(undefined),
    };
    const realProcessor = createOutboxEventProcessor(
      calendarSync as never,
      syncIssues as unknown as SyncIssuesService,
      config,
    );

    await expect(realProcessor(firstEvent)).resolves.toBeUndefined();
    expect(syncIssues.finalizeFailure).toHaveBeenCalledWith(
      firstEvent,
      expect.objectContaining({
        code: 'CALENDAR_UNAVAILABLE',
        retryable: true,
      }),
      config,
    );
    expect(JSON.stringify(syncIssues.finalizeFailure.mock.calls)).not.toContain(
      'private provider detail',
    );
  });

  it('maps a raw provider reauthentication error to a terminal safe failure', async () => {
    const calendarSync = {
      process: jest
        .fn()
        .mockRejectedValue(
          new CalendarProviderError(
            'CALENDAR_REAUTH_REQUIRED',
            'private auth detail',
          ),
        ),
    };
    const syncIssues = {
      finalizeSuccess: jest.fn(),
      finalizeFailure: jest.fn().mockResolvedValue(undefined),
    };
    const realProcessor = createOutboxEventProcessor(
      calendarSync as never,
      syncIssues as unknown as SyncIssuesService,
      config,
    );

    await realProcessor(firstEvent);

    expect(syncIssues.finalizeFailure).toHaveBeenCalledWith(
      firstEvent,
      {
        code: 'CALENDAR_REAUTH_REQUIRED',
        message: 'La conexión de Google requiere autorización nuevamente',
        retryable: false,
      },
      config,
    );
  });

  it('does not overlap local drains', async () => {
    config.batchSize = 1;
    transaction.$queryRaw.mockResolvedValueOnce([
      {
        id: firstEvent.id,
        aggregate_id: firstEvent.aggregateId,
        type: firstEvent.type,
        payload: firstEvent.payload,
        attempts: firstEvent.attempts,
      },
    ]);
    let release!: () => void;
    let started!: () => void;
    const startedPromise = new Promise<void>((resolve) => {
      started = resolve;
    });
    const releasePromise = new Promise<void>((resolve) => {
      release = resolve;
    });
    processor.mockImplementation(async () => {
      started();
      await releasePromise;
    });

    const firstDrain = worker.drainOnce();
    await startedPromise;
    const secondDrain = worker.drainOnce();

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    release();
    await expect(Promise.all([firstDrain, secondDrain])).resolves.toEqual([
      1, 1,
    ]);
  });

  it('registers a named interval only when enabled and removes it during shutdown', async () => {
    const intervalHandle = {} as NodeJS.Timeout;
    const setIntervalSpy = jest
      .spyOn(global, 'setInterval')
      .mockReturnValue(intervalHandle);
    const disabledWorker = new OutboxWorkerService(
      prisma as unknown as PrismaService,
      { ...config, enabled: false },
      scheduler,
      processor,
    );

    disabledWorker.onModuleInit();
    expect(setIntervalSpy).not.toHaveBeenCalled();

    worker.onModuleInit();
    expect(setIntervalSpy).toHaveBeenCalledWith(
      expect.any(Function),
      config.pollIntervalMs,
    );
    expect(scheduler.addInterval).toHaveBeenCalledWith(
      OUTBOX_WORKER_INTERVAL,
      intervalHandle,
    );

    await worker.beforeApplicationShutdown('SIGTERM');
    expect(scheduler.deleteInterval).toHaveBeenCalledWith(
      OUTBOX_WORKER_INTERVAL,
    );
    setIntervalSpy.mockRestore();
  });

  it('waits for an active drain before completing shutdown', async () => {
    config.batchSize = 1;
    transaction.$queryRaw.mockResolvedValueOnce([
      {
        id: firstEvent.id,
        aggregate_id: firstEvent.aggregateId,
        type: firstEvent.type,
        payload: firstEvent.payload,
        attempts: firstEvent.attempts,
      },
    ]);
    let release!: () => void;
    const releasePromise = new Promise<void>((resolve) => {
      release = resolve;
    });
    processor.mockImplementation(async () => releasePromise);

    const drain = worker.drainOnce();
    await Promise.resolve();
    const shutdown = worker.beforeApplicationShutdown();
    let shutdownFinished = false;
    void shutdown.then(() => {
      shutdownFinished = true;
    });
    await Promise.resolve();

    expect(shutdownFinished).toBe(false);
    release();
    await drain;
    await shutdown;
    expect(shutdownFinished).toBe(true);
  });
});
