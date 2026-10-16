import { Module } from '@nestjs/common';
import { ScheduleModule, SchedulerRegistry } from '@nestjs/schedule';

import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { PrismaModule } from '../database/prisma.module';
import { OutboxWorkerService } from './outbox-worker.service';
import { SCHEDULER_REGISTRY, SYNC_CONFIG } from './sync.constants';
import { readSyncConfig } from './sync.config';

@Module({
  imports: [ScheduleModule.forRoot(), PrismaModule, CalendarModule, AuthModule],
  providers: [
    {
      provide: SYNC_CONFIG,
      useFactory: () => readSyncConfig(process.env),
    },
    {
      provide: SCHEDULER_REGISTRY,
      useExisting: SchedulerRegistry,
    },
    OutboxWorkerService,
  ],
  exports: [OutboxWorkerService],
})
export class SyncModule {}
