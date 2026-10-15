import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { AdminBlocksController } from './admin-blocks.controller';
import { AdminBlocksService } from './admin-blocks.service';
import { AdminAvailabilityController } from './admin-availability.controller';
import { AdminAvailabilityService } from './admin-availability.service';

@Module({
  imports: [AuthModule],
  controllers: [AdminAvailabilityController, AdminBlocksController],
  providers: [AdminAvailabilityService, AdminBlocksService],
})
export class AvailabilityModule {}
