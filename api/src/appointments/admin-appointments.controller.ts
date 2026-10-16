import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import {
  AdminSessionGuard,
  type AuthenticatedRequest,
} from '../auth/admin-session.guard';
import {
  AppointmentActionDto,
  ListAdminAppointmentsDto,
  RescheduleAdminAppointmentDto,
} from './admin-appointments.dto';
import { AdminAppointmentsService } from './admin-appointments.service';

@Controller('admin/appointments')
@UseGuards(AdminSessionGuard)
export class AdminAppointmentsController {
  constructor(private readonly appointments: AdminAppointmentsService) {}

  @Get()
  list(
    @Req() request: AuthenticatedRequest,
    @Query() query: ListAdminAppointmentsDto,
  ) {
    return this.appointments.list(request.user.id, query);
  }

  @Get(':id')
  detail(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    return this.appointments.detail(request.user.id, id);
  }

  @Patch(':id/reschedule')
  reschedule(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: RescheduleAdminAppointmentDto,
  ) {
    return this.appointments.reschedule(request.user.id, id, dto);
  }

  @Post(':id/cancel')
  cancel(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: AppointmentActionDto,
  ) {
    return this.appointments.cancel(request.user.id, id, dto);
  }

  @Post(':id/complete')
  complete(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: AppointmentActionDto,
  ) {
    return this.appointments.complete(request.user.id, id, dto);
  }

  @Post(':id/no-show')
  noShow(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: AppointmentActionDto,
  ) {
    return this.appointments.noShow(request.user.id, id, dto);
  }
}
