import { Module } from '@nestjs/common';

import { AvailabilityModule } from '../availability/availability.module';
import { RequestsModule } from '../requests/requests.module';
import { PublicConfirmationController } from './public-confirmation.controller';
import { PublicConfirmationService } from './public-confirmation.service';

@Module({
  imports: [AvailabilityModule, RequestsModule],
  controllers: [PublicConfirmationController],
  providers: [PublicConfirmationService],
})
export class AppointmentsModule {}
