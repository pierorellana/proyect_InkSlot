import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PublicReservationsController } from './public-reservations.controller';
import { BookingRequestsController } from './requests.controller';
import { BookingRequestsService } from './requests.service';

@Module({
  imports: [AuthModule],
  controllers: [BookingRequestsController, PublicReservationsController],
  providers: [BookingRequestsService],
  exports: [BookingRequestsService],
})
export class RequestsModule {}
