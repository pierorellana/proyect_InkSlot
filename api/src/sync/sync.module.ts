import { Module } from '@nestjs/common';
import { ScheduleModule, SchedulerRegistry } from '@nestjs/schedule';

import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { PrismaModule } from '../database/prisma.module';
import { CalendarSyncService } from './calendar-sync.service';
import {
  createOutboxEventProcessor,
  OutboxWorkerService,
} from './outbox-worker.service';
import {
  OUTBOX_EVENT_PROCESSOR,
  SCHEDULER_REGISTRY,
  SYNC_CONFIG,
  SYNC_RANDOM,
} from './sync.constants';
import { readSyncConfig } from './sync.config';
import { SyncIssuesService } from './sync-issues.service';
import { SyncIssuesController } from './sync-issues.controller';

@Module({
  imports: [ScheduleModule.forRoot(), PrismaModule, CalendarModule, AuthModule],
  controllers: [SyncIssuesController],
  providers: [
    {
      provide: SYNC_CONFIG,
      useFactory: () => readSyncConfig(process.env),
    },
    {
      provide: SCHEDULER_REGISTRY,
      useExisting: SchedulerRegistry,
    },
    {
      provide: SYNC_RANDOM,
      useValue: Math.random,
    },
    CalendarSyncService,
    SyncIssuesService,
    {
      provide: OUTBOX_EVENT_PROCESSOR,
      useFactory: createOutboxEventProcessor,
      inject: [CalendarSyncService, SyncIssuesService, SYNC_CONFIG],
    },
    OutboxWorkerService,
  ],
  exports: [OutboxWorkerService, SyncIssuesService],
})
export class SyncModule {}
