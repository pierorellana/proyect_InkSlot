import {
  BeforeApplicationShutdown,
  Inject,
  Injectable,
  OnModuleInit,
  Optional,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../database/prisma.service';
import {
  OUTBOX_EVENT_PROCESSOR,
  OUTBOX_WORKER_INTERVAL,
  SCHEDULER_REGISTRY,
  type ClaimedOutboxEvent,
  type OutboxEventProcessor,
  type SchedulerRegistryPort,
  SYNC_CONFIG,
  type SyncConfig,
} from './sync.constants';

type RawClaimedOutboxEvent = {
  id: string;
  aggregate_id: string;
  type: string;
  payload: unknown;
  attempts: number;
};

@Injectable()
export class OutboxWorkerService
  implements OnModuleInit, BeforeApplicationShutdown
{
  private activeDrain: Promise<number> | null = null;
  private shutdownRequested = false;
  private intervalRegistered = false;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(SYNC_CONFIG) private readonly config: SyncConfig,
    @Inject(SCHEDULER_REGISTRY)
    private readonly scheduler: SchedulerRegistryPort,
    @Optional()
    @Inject(OUTBOX_EVENT_PROCESSOR)
    private readonly processor?: OutboxEventProcessor,
  ) {}

  onModuleInit(): void {
    if (!this.config.enabled || this.shutdownRequested) return;

    const interval = setInterval(() => {
      if (this.shutdownRequested) return;
      void this.drainOnce().catch(() => undefined);
    }, this.config.pollIntervalMs);

    this.scheduler.addInterval(OUTBOX_WORKER_INTERVAL, interval);
    this.intervalRegistered = true;
  }

  async beforeApplicationShutdown(): Promise<void> {
    this.shutdownRequested = true;

    if (this.intervalRegistered) {
      this.scheduler.deleteInterval(OUTBOX_WORKER_INTERVAL);
      this.intervalRegistered = false;
    }

    await this.activeDrain?.catch(() => undefined);
  }

  drainOnce(): Promise<number> {
    if (this.activeDrain) return this.activeDrain;
    if (this.shutdownRequested) return Promise.resolve(0);

    const drain = this.runDrain();
    this.activeDrain = drain;
    void drain.then(
      () => this.clearActiveDrain(drain),
      () => this.clearActiveDrain(drain),
    );
    return drain;
  }

  private clearActiveDrain(drain: Promise<number>): void {
    if (this.activeDrain === drain) this.activeDrain = null;
  }

  private async runDrain(): Promise<number> {
    let claimed = 0;

    while (!this.shutdownRequested && claimed < this.config.batchSize) {
      const event = await this.claimNext();
      if (!event) break;

      claimed += 1;
      try {
        await this.processor?.(event);
      } catch {
        // Task 4 will persist a safe failure. A single event must not stop the batch.
      }
    }

    return claimed;
  }

  private async claimNext(): Promise<ClaimedOutboxEvent | null> {
    return this.prisma.$transaction(async (transaction) => {
      const rows = await transaction.$queryRaw<RawClaimedOutboxEvent[]>(
        Prisma.sql`
          WITH candidate AS (
            SELECT id
            FROM "outbox_events"
            WHERE (
              (status = 'PENDING' AND (next_attempt_at IS NULL OR next_attempt_at <= NOW()))
              OR (status = 'PROCESSING' AND next_attempt_at <= NOW())
            )
            ORDER BY COALESCE(next_attempt_at, created_at), created_at, id
            FOR UPDATE SKIP LOCKED
            LIMIT 1
          )
          UPDATE "outbox_events" AS event
          SET status = 'PROCESSING',
              attempts = event.attempts + 1,
              next_attempt_at = NOW() + (${this.config.leaseMs} * INTERVAL '1 millisecond')
          FROM candidate
          WHERE event.id = candidate.id
          RETURNING event.id, event.aggregate_id, event.type, event.payload, event.attempts
        `,
      );
      const row = rows[0];
      if (!row) return null;

      return {
        id: row.id,
        aggregateId: row.aggregate_id,
        type: row.type,
        payload: row.payload,
        attempts: row.attempts,
      };
    });
  }
}
