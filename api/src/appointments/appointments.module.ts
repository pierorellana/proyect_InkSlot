import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { AvailabilityModule } from '../availability/availability.module';
import { PrismaModule } from '../database/prisma.module';
import { RequestsModule } from '../requests/requests.module';
import { AdminAppointmentsController } from './admin-appointments.controller';
import { AdminAppointmentsService } from './admin-appointments.service';
import { PublicConfirmationController } from './public-confirmation.controller';
import { PublicConfirmationService } from './public-confirmation.service';

@Module({
  imports: [AuthModule, AvailabilityModule, PrismaModule, RequestsModule],
  controllers: [AdminAppointmentsController, PublicConfirmationController],
  providers: [AdminAppointmentsService, PublicConfirmationService],
})
export class AppointmentsModule {}
