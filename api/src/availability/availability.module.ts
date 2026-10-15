import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { AdminAvailabilityController } from './admin-availability.controller';
import { AdminAvailabilityService } from './admin-availability.service';

@Module({
  imports: [AuthModule],
  controllers: [AdminAvailabilityController],
  providers: [AdminAvailabilityService],
})
export class AvailabilityModule {}
