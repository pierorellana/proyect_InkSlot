import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { RequestsModule } from '../requests/requests.module';
import { AdminBlocksController } from './admin-blocks.controller';
import { AdminBlocksService } from './admin-blocks.service';
import { AdminAvailabilityController } from './admin-availability.controller';
import { AdminAvailabilityService } from './admin-availability.service';
import { AvailabilityEngine } from './availability.engine';
import { PublicAvailabilityController } from './public-availability.controller';
import { PublicAvailabilityService } from './public-availability.service';

@Module({
  imports: [AuthModule, RequestsModule, CalendarModule],
  controllers: [
    AdminAvailabilityController,
    AdminBlocksController,
    PublicAvailabilityController,
  ],
  providers: [
    AdminAvailabilityService,
    AdminBlocksService,
    AvailabilityEngine,
    PublicAvailabilityService,
  ],
  exports: [AvailabilityEngine, PublicAvailabilityService],
})
export class AvailabilityModule {}
