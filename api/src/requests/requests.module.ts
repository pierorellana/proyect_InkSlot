import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { BookingRequestsController } from './requests.controller';
import { BookingRequestsService } from './requests.service';

@Module({
  imports: [AuthModule],
  controllers: [BookingRequestsController],
  providers: [BookingRequestsService],
  exports: [BookingRequestsService],
})
export class RequestsModule {}

